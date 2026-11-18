-- perfREV: pure calculations, independent of REAPER.
local M = {}

function M.finite(v)
  return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function M.clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

local function positive(v, name)
  assert(M.finite(v) and v > 0, (name or "Value") .. " must be positive and finite")
  return v
end

function M.note_ms(bpm, denominator, variant)
  local factors = {straight = 1, dotted = 1.5, triplet = 2 / 3}
  assert(factors[variant or "straight"], "Unknown note variant")
  return 60000 / positive(bpm, "BPM") * 4 / positive(denominator, "Denominator")
    * factors[variant or "straight"]
end

function M.bar_ms(bpm, numerator, denominator)
  return M.note_ms(bpm, denominator) * positive(numerator, "Numerator")
end

function M.decay_label(seconds)
  if seconds < 1 then return "Breve" end
  if seconds <= 2 then return "Medio" end
  return "Lungo"
end

-- Ideal, linear, unfiltered feedback delay. Not a universal plugin mapping.
function M.feedback_rt60(delay_ms, feedback)
  positive(delay_ms, "Delay")
  assert(M.finite(feedback) and feedback > 0 and feedback < 1, "Feedback must be between 0 and 1")
  return delay_ms / 1000 * math.log(0.001) / math.log(feedback)
end

function M.new_tap()
  return {times = {}, bpm = nil, variation = nil}
end

function M.tap(tap, now)
  assert(M.finite(now), "Invalid timestamp")
  local times = tap.times
  local last = times[#times]
  if last and (now - last > 3 or now <= last) then
    times = {}
    tap.times, tap.bpm, tap.variation = times, nil, nil
    last = nil
  end
  if last and now - last < 0.1 then return tap.bpm, #times end
  times[#times + 1] = now
  if #times > 9 then table.remove(times, 1) end
  if #times >= 2 then
    local mean = (times[#times] - times[1]) / (#times - 1)
    local sum = 0
    for i = 2, #times do sum = sum + ((times[i] - times[i - 1]) - mean) ^ 2 end
    tap.bpm = 60 / mean
    tap.variation = math.sqrt(sum / (#times - 1)) / mean * 100
  end
  return tap.bpm, #times
end

function M.speed(temperature)
  assert(M.finite(temperature) and temperature >= -20 and temperature <= 50,
    "Temperature must be between -20 and 50 C")
  return 331.3 * math.sqrt((273.15 + temperature) / 273.15)
end

local function distance(a, b)
  return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end
M.distance = distance

function M.validate_room(r)
  for _, key in ipairs({"width", "length", "height"}) do positive(r[key], key) end
  M.speed(r.temperature)
  for _, p in ipairs({r.source, r.listener}) do
    assert(type(p) == "table", "Missing source/listener")
    for _, axis in ipairs({"x", "y", "z"}) do
      local extent = ({x = r.width, y = r.length, z = r.height})[axis]
      assert(M.finite(p[axis]) and p[axis] > 0 and p[axis] < extent,
        "Source and listener must be inside the room")
    end
  end
  assert(distance(r.source, r.listener) >= 0.05, "Source/listener distance must be at least 5 cm")
  assert(type(r.absorption) == "table" and #r.absorption == 6, "Six absorption values required")
  for _, a in ipairs(r.absorption) do
    assert(M.finite(a) and a >= 0 and a <= 1, "Absorption must be between 0 and 1")
  end
  return true
end

function M.room(r)
  M.validate_room(r)
  local c, s, l = M.speed(r.temperature), r.source, r.listener
  local d = distance(s, l)
  local surfaces = {
    {name = "Sinistra", axis = "x", plane = 0, area = r.length * r.height},
    {name = "Destra", axis = "x", plane = r.width, area = r.length * r.height},
    {name = "Fronte", axis = "y", plane = 0, area = r.width * r.height},
    {name = "Retro", axis = "y", plane = r.length, area = r.width * r.height},
    {name = "Pavimento", axis = "z", plane = 0, area = r.width * r.length},
    {name = "Soffitto", axis = "z", plane = r.height, area = r.width * r.length},
  }
  local reflections, total_area, equivalent = {}, 0, 0
  for i, wall in ipairs(surfaces) do
    local image = {x = s.x, y = s.y, z = s.z}
    image[wall.axis] = 2 * wall.plane - s[wall.axis]
    local path = distance(image, l)
    local t = (wall.plane - l[wall.axis]) / (image[wall.axis] - l[wall.axis])
    local hit = {}
    for _, axis in ipairs({"x", "y", "z"}) do hit[axis] = l[axis] + t * (image[axis] - l[axis]) end
    -- Listener faces toward decreasing y. Degrees: 0 front, +90 right, +/-180 back.
    local azimuth = math.deg(math.atan(image.x - l.x, l.y - image.y))
    local horizontal = math.sqrt((image.x - l.x)^2 + (image.y - l.y)^2)
    local elevation = math.deg(math.atan(image.z - l.z, horizontal))
    local amplitude = math.sqrt(1 - r.absorption[i]) * d / path
    reflections[#reflections + 1] = {
      name = wall.name, wall = i, path = path, hit = hit,
      arrival_ms = path / c * 1000, delay_ms = (path - d) / c * 1000,
      db = amplitude > 0 and 20 * math.log(amplitude, 10) or -math.huge,
      azimuth = azimuth, elevation = elevation, amplitude = amplitude,
    }
    total_area = total_area + wall.area
    equivalent = equivalent + wall.area * r.absorption[i]
  end
  table.sort(reflections, function(a, b)
    if a.delay_ms == b.delay_ms then return a.wall < b.wall end
    return a.delay_ms < b.delay_ms
  end)
  local volume = r.width * r.length * r.height
  local alpha = equivalent / total_area
  local k = 24 * math.log(10) / c
  local sabine = equivalent > 0 and k * volume / equivalent or math.huge
  local eyring = alpha == 0 and math.huge
    or (alpha == 1 and 0 or k * volume / (-total_area * math.log(1 - alpha)))
  local modes = {}
  for _, item in ipairs({{"Larghezza", r.width}, {"Lunghezza", r.length}, {"Altezza", r.height}}) do
    for n = 1, 3 do modes[#modes + 1] = {axis = item[1], order = n, hz = c / (2 * item[2]) * n} end
  end
  table.sort(modes, function(a, b) return a.hz < b.hz end)
  return {
    speed = c, distance = d, direct_ms = d / c * 1000,
    direct_db_1m = -20 * math.log(d, 10),
    reflections = reflections, volume = volume, area = total_area,
    alpha = alpha, sabine = sabine, eyring = eyring, modes = modes,
  }
end

function M.number(v, decimals)
  if v == math.huge then return "infinito" end
  if v == -math.huge then return "-inf" end
  return string.format("%." .. (decimals or 2) .. "f", v)
end

return M
