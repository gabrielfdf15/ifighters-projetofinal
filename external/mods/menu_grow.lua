-- menu_grow.lua
-- Anima suavemente o tamanho dos itens do menu principal (tela de titulo):
-- o item selecionado cresce e o que perdeu o foco volta ao normal.
-- Funciona com qualquer fonte, porque so mexe na escala do texto.
--
-- Instalacao: coloque este arquivo em external/mods/ (carrega sozinho).
-- Alternativa: aponte para ele em  module =  no [Files] do system.def.

local CFG = {
	grow   = 1.3,  -- multiplicador do item selecionado (1.3 = 30% maior)
	speed  = 0.42, -- fracao do caminho percorrida por frame (0.1 = lento, 0.4 = rapido)
	yShift = 0,    -- pixels para empurrar o texto para baixo ao crescer (ajuste se
	               -- o item parecer subir; a escala cresce a partir da linha base)
}

local function warn(msg)
	print('[menu_grow] ' .. tostring(msg))
end

local function install()
	if main == nil or motif == nil or type(main.f_menuCommonDraw) ~= 'function' then
		warn('main.f_menuCommonDraw nao encontrado; modulo desativado.')
		return
	end
	if type(textImgSetScale) ~= 'function' or type(textImgAddPos) ~= 'function' then
		warn('textImgSetScale nao existe nesta versao; modulo desativado.')
		return
	end
	if main.__menuGrowInstalled then
		return
	end
	main.__menuGrowInstalled = true

	local state = {}        -- nome do item -> multiplicador atual
	local sprites = {}      -- TextSpriteData dos itens do menu -> true
	local baseScale = {1, 1}
	local drawing = false   -- true enquanto desenha o menu do titulo
	local lastKey = nil     -- texto do ultimo item configurado
	local errored = false

	local function prepare(t, item, sec)
		local m = sec.menu
		sprites = {}
		local function add(node)
			if node and node.TextSpriteData then
				sprites[node.TextSpriteData] = true
			end
		end
		add(m.item)
		add(m.item.active)
		if m.item.selected then
			add(m.item.selected)
			add(m.item.selected.active)
		end
		local bs = m.item.scale
		if type(bs) == 'table' and type(bs[1]) == 'number' and type(bs[2]) == 'number' then
			baseScale = {bs[1], bs[2]}
		else
			baseScale = {1, 1}
		end
		local keys = {}
		for i, itemData in ipairs(t) do
			local key = main.f_itemnameUpper(itemData.displayname, m.item.uppercase)
			if itemData.itemname:match('^spacer%d*$') then
				key = ''
			end
			keys[i] = key
		end
		local activeKey = keys[item]
		for _, key in pairs(keys) do
			local target = (key == activeKey) and CFG.grow or 1
			local s = state[key] or 1
			s = s + (target - s) * CFG.speed
			if math.abs(target - s) < 0.003 then
				s = target
			end
			state[key] = s
		end
	end

	-- 1) uma vez por frame: atualiza a animacao de cada item do titulo
	local origCommonDraw = main.f_menuCommonDraw
	main.f_menuCommonDraw = function(t, item, cursorPosY, moveTxt, sec, bg, skipClear, opts)
		drawing = false
		if not errored and sec == motif.title_info and sec.menu ~= nil and t ~= nil and t[item] ~= nil then
			local ok, err = pcall(prepare, t, item, sec)
			if ok then
				drawing = true
			else
				errored = true
				warn(err)
			end
		end
		-- a funcao original nao retorna nada (termina em refresh())
		origCommonDraw(t, item, cursorPosY, moveTxt, sec, bg, skipClear, opts)
		drawing = false
	end

	-- 2) descobre qual item esta sendo desenhado (o texto e definido antes do draw)
	local origSetText = textImgSetText
	textImgSetText = function(ts, text, ...)
		if drawing and sprites[ts] then
			lastKey = text
		end
		return origSetText(ts, text, ...)
	end

	-- 3) aplica a escala logo antes de desenhar
	local origDraw = textImgDraw
	textImgDraw = function(ts, ...)
		if drawing and sprites[ts] and lastKey ~= nil then
			local s = state[lastKey]
			if s ~= nil then
				textImgSetScale(ts, baseScale[1] * s, baseScale[2] * s)
				if CFG.yShift ~= 0 then
					textImgAddPos(ts, 0, CFG.yShift * (s - 1))
				end
			end
		end
		return origDraw(ts, ...)
	end
end

local ok, err = pcall(install)
if not ok then
	warn(err)
end
