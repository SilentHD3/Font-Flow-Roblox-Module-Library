--// Rich Text By SilentHD3

local MainModule = {}
MainModule.__index = MainModule

-- Utility Functions

--this is an explain for checking if value is table
local function isTable(v)
	return typeof(v) == "table"
end

--this is an explain for converting Color3 to hex string
local function toHex(color: Color3)
	local r = math.floor(color.R * 255)
	local g = math.floor(color.G * 255)
	local b = math.floor(color.B * 255)
	return string.format("#%02X%02X%02X", r, g, b)
end

-- Rich Text Helpers

--this is an explain for getting font tag
local function getFont(font)
	if typeof(font) == "EnumItem" and font.EnumType == Enum.Font then
		font = font.Name
	end
	return `<font face="{font}">`
end

--this is an explain for getting color tag
local function getColor(color)
	if typeof(color) == "Color3" then
		color = toHex(color)
	end
	return `<font color="{color}">`
end

--this is an explain for getting size tag
local function getSize(size)
	return `<font size="{size}">`
end

--this is an explain for getting mark tag
local function getMark(color)
	if typeof(color) == "Color3" then
		color = toHex(color)
	end
	return `<mark color="{color}">`
end

--this is an explain for getting stroke tag
local function getStroke(stroke)
	local color = stroke.Color or "#000000"
	if typeof(color) == "Color3" then
		color = toHex(color)
	end
	local thickness = stroke.Thickness or 1
	return `<stroke color="{color}" thickness="{thickness}">`
end

--this is an explain for getting style open tag
local function getStyle(style)
	if style == "Bold" then
		return "<b>"
	elseif style == "Italic" then
		return "<i>"
	elseif style == "Underline" then
		return "<u>"
	end
	return ""
end

--this is an explain for getting style close tag
local function closeStyle(style)
	if style == "Bold" then
		return "</b>"
	elseif style == "Italic" then
		return "</i>"
	elseif style == "Underline" then
		return "</u>"
	end
	return ""
end

-- Themes

--this is an explain for built in themes
local Themes = {
	Error = {
		Color = "#FF0000",
		Font = "GothamBold",
		Style = "Bold",
		Size = 20,
	},
	Success = {
		Color = "#00FF00",
		Font = "Gotham",
		Style = "Italic",
		Size = 18,
	},
	Warning = {
		Color = "#FFFF00",
		Font = "Arial",
		Style = "Bold",
		Size = 19,
	},
}

--this is an explain for getting theme data
local function getTheme(name)
	return Themes[name]
end

-- Text Transform

--this is an explain for uppercase & smallcaps
local function applyTextTransform(word, data)
	if data.Uppercase then
		return string.upper(word)
	elseif data.SmallCaps then
		return string.upper(word)
	end
	return word
end

-- Constructor

--this is an explain for creating new rich text object
function MainModule.new(text: string)
	local self = setmetatable({}, MainModule)
	self.OriginalText = text
	self.Words = string.split(text, " ")
	return self
end

-- Apply Rich Data

--this is an explain for applying rich text to word indexes
function MainModule:Apply(indexes, data)
	local function applyToIndex(i)
		assert(self.Words[i], `Invalid word index: {i}`)

		if data.LineBreak then
			self.Words[i] = self.Words[i] .. "<br />"
			return
		end

		if data.Comment then
			self.Words[i] = "<!-- " .. self.Words[i] .. " -->"
			return
		end

		local word = applyTextTransform(self.Words[i], data)
		local openTag = ""
		local closeTag = ""

		if data.Font then
			openTag ..= getFont(data.Font)
			closeTag = "</font>" .. closeTag
		end

		if data.Color then
			openTag ..= getColor(data.Color)
			closeTag = "</font>" .. closeTag
		end

		if data.Size then
			openTag ..= getSize(data.Size)
			closeTag = "</font>" .. closeTag
		end

		if data.Style then
			if data.Style == "Strikethrough" then
				openTag ..= "<s>"
				closeTag = "</s>" .. closeTag
			else
				openTag ..= getStyle(data.Style)
				closeTag = closeStyle(data.Style) .. closeTag
			end
		end

		if data.Stroke then
			openTag ..= getStroke(data.Stroke)
			closeTag = "</stroke>" .. closeTag
		end

		if data.Mark then
			openTag ..= getMark(data.Mark)
			closeTag = "</mark>" .. closeTag
		end

		if data.Transparency then
			openTag ..= `<font transparency="{data.Transparency}">`
			closeTag = "</font>" .. closeTag
		end

		self.Words[i] = openTag .. word .. closeTag
	end

	if isTable(indexes) then
		for _, i in ipairs(indexes) do
			applyToIndex(i)
		end
	else
		applyToIndex(indexes)
	end
end

-- Theme Apply

--this is an explain for applying a theme
function MainModule:ApplyTheme(indexes, themeName)
	local theme = getTheme(themeName)
	self:Apply(indexes, theme)
end

-- Quick Generate

--this is an explain for fast font + color styling
function MainModule:ShortGenerate(indexes, font, color)
	self:Apply(indexes, {
		Font = font,
		Color = color,
	})
end

-- Build Final Text

--this is an explain for building final rich text string
function MainModule:Build()
	return table.concat(self.Words, " ")
end

-- Public API

return {
	New = function(text)
		return MainModule.new(text)
	end,

	Themes = Themes,

	Short = function(text, indexes, font, color)
		local obj = MainModule.new(text)
		obj:ShortGenerate(indexes, font, color)
		return obj:Build()
	end,
}
