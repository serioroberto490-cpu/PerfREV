-- Reverb reference data. No audio processing and no REAPER/plugin calls.
local M = {}
M.types = {
  {"Hall 1","Hall"}, {"Hall 2","Hall"}, {"Room","Room"}, {"Chamber","Chamber"},
  {"Church","Church"}, {"Plate 1","Plate"}, {"Plate 2","Plate"}, {"Reverse","Reverse"},
  {"Gated","Gated"}, {"Non-Linear","Non-linear"}, {"EchoVerb","Echo / multitap"},
  {"ResoVerb","Resonant"}, {"Spring","Spring"}, {"Ambience","Ambience"},
  {"Convolution / IR","Convolution / IR"}, {"Personalizzato","Personalizzato"},
}
M.rverb_types = 12

function M.category(seconds)
  if seconds < 1 then
    return "Corto", "Coda contenuta: ambiente e coesione, senza troppo sustain.",
      "Prova su parti fitte, batteria o una voce da tenere in primo piano."
  elseif seconds <= 2 then
    return "Medio", "Coda percepibile: profondita' e spazio fra le frasi.",
      "Prova su strofe, voce solista e strumenti melodici; controlla le pause."
  end
  return "Lungo", "Coda evidente: avvolgente, puo' sovrapporsi a note e accordi.",
    "Prova su pad, ritornelli o finali di frase; riduci il send se maschera."
end

function M.time_ms(s, bpm)
  if s.rev_time_mode == "free" then return s.rev_time_s * 1000 end
  return 60000 / bpm * s.decay_q
end

local function n(value, decimals) return string.format("%."..(decimals or 2).."f",value) end
function M.type_name(s)
  if s.rev_type==#M.types and s.rev_custom_type and s.rev_custom_type~="" then return s.rev_custom_type end
  return M.types[s.rev_type][1]
end

function M.warnings(s, bpm)
  local warnings = {}
  local ms = M.time_ms(s,bpm)
  if s.rev_profile == "rverb" then
    if ms < 100 or ms > 20000 then
      warnings[#warnings+1] = "RVerb Time: fuori range 0.1-20 s. Valore conservato, non limitato."
    end
    if s.predelay < -160 or s.predelay > 160 then
      warnings[#warnings+1] = "RVerb Pre-delay: fuori range -160/+160 ms. Nessun clamp automatico."
    end
    if s.rev_type > M.rverb_types then
      warnings[#warnings+1] = "Tipo non presente in RVerb: scegli un altro plugin o un altro tipo."
    end
    if s.rev_size < 1 or s.rev_diffusion < 1 then
      warnings[#warnings+1] = "Size / Diffusion RVerb: il manuale indica 1-100%. Controlla il plugin."
    end
    if s.rev_early > 0 or s.rev_early < -40 or s.rev_tail > 0 or s.rev_tail < -40 then
      warnings[#warnings+1] = "Livelli RVerb ER/Reverb: -40 (off)..0 dB; i valori generici restano liberi."
    end
    if s.rev_gain < -24 or s.rev_gain > 0 then
      warnings[#warnings+1] = "Gain RVerb: -24..0 dB. Il gain scelto resta invariato."
    end
  end
  if s.predelay < 0 then
    warnings[#warnings+1] = "Pre-delay negativo: in RVerb ritarda il dry, con possibile perdita di sync."
  end
  if s.rev_route == "send" and s.rev_wet ~= 100 then
    warnings[#warnings+1] = "Su bus send si consiglia Wet/Dry 100%: evita un secondo dry involontario."
  end
  if s.rev_type == 8 or s.rev_type == 9 or s.rev_type == 10 then
    warnings[#warnings+1] = "Reverse/Gated/Non-Linear: Time puo' descrivere l'inviluppo, non un RT60 lineare."
  end
  return warnings
end

-- Values other than time are user choices, not derived from BPM or room geometry.
function M.rows(s, bpm)
  local is_rverb = s.rev_profile == "rverb"
  local ms = M.time_ms(s,bpm)
  return {
    {"Tempo coda / RT60", is_rverb and "Time" or "Time / Reverb time / Decay",
      n(ms/1000,3).." s  ("..n(ms,2).." ms)", "Calcolato se musicale; libero in secondi. Non una fine netta."},
    {"Pre-delay", "Pre-delay", n(s.predelay,2).." ms",
      is_rverb and "RVerb: separa la coda da dry + ER, non sposta tutte le riflessioni."
        or "Il punto di applicazione dipende dal plugin: controlla il manuale."},
    {"Tipo / algoritmo", is_rverb and "Reverb Type" or "Type / Algorithm / IR",
      M.type_name(s), "Scelta creativa indipendente da corto/medio/lungo; nessuna selezione forzata."},
    {"Dimensione", "Size", n(s.rev_size,1).."%", "Scelta relativa al plugin, non metri o volume fisico."},
    {"Diffusione", "Diffusion", n(s.rev_diffusion,1).."%",
      is_rverb and "RVerb: bilancia dry/ER che alimentano la coda; non unita' universale."
        or "Dispersione/densita' percepita: significato e scala cambiano col plugin."},
    {"Forma della coda", is_rverb and "Decay" or "Shape / Decay curve (se disponibile)",
      is_rverb and n(s.rev_shape,2)..(s.rev_shape==3.5 and " (linear)" or "") or "Specifico del plugin",
      "RVerb Decay NON e' Time: 0.04-3.5, con 3.5 lineare; valori bassi troncano la coda."},
    {"Prime riflessioni", is_rverb and "Early Reflections" or "Early / ER level",
      n(s.rev_early,1).." dB", "Livello scelto a orecchio; RVerb -40 dB = off."},
    {"Livello coda", is_rverb and "Reverb" or "Late / Tail level",
      n(s.rev_tail,1).." dB", "Equilibrio con le ER, non distanza in metri."},
    {"Quantita' effetto", "Wet/Dry", n(s.rev_wet,1).."%",
      s.rev_route=="send" and "Bus send: raccomandato 100% wet; dosa con il send."
        or "Insert: dosa wet/dry nel plugin e confronta a volume coerente."},
    {"Damping basse", is_rverb and "Low Freq / Ratio" or "LF damping / Decay ratio",
      n(s.rev_lf,0).." Hz / "..n(s.rev_lratio,2), "Scelta manuale. 1.00 e' neutro; controlla il verso del rapporto nel plugin."},
    {"Damping alte", is_rverb and "High Freq / Ratio" or "HF damping / Decay ratio",
      n(s.rev_hf,0).." Hz / "..n(s.rev_hratio,2), "Damping cambia il decadimento per banda; non equivale a un semplice EQ."},
    {"EQ basse coda", is_rverb and "EQ Low Freq / Gain" or "EQ low shelf / Filter",
      n(s.rev_eqlf,0).." Hz / "..n(s.rev_eqlgain,1).." dB", "Shelf e passa-alto non sono equivalenti. Verifica frequenze disponibili."},
    {"EQ alte coda", is_rverb and "EQ High Freq / Gain" or "EQ high shelf / Filter",
      n(s.rev_eqhf,0).." Hz / "..n(s.rev_eqhgain,1).." dB", "Valori di partenza modificabili: nessun taglio imposto a tutte le sorgenti."},
    {"Stereo / decorrelazione", is_rverb and "Decorrelation" or "Width / Decorrelation (specifico)",
      is_rverb and "Variation "..s.rev_decorr or "Specifico del plugin",
      "RVerb Variation 0-6, non percentuale di width. Controlla la compatibilita' mono."},
    {"Uscita", is_rverb and "Gain" or "Output gain", n(s.rev_gain,1).." dB", "Evita clipping; il calcolatore non misura o normalizza il segnale."},
  }
end
return M
