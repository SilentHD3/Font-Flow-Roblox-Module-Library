-- main table that will hold all functions
local MainModule = {}
MainModule.__index = MainModule

-- check if value is a table
local function isTable(v)
	return typeof(v) == "table"
end

-- convert Color3 to HEX (#RRGGBB)
local function toHex(color: Color3)
	local r = math.floor(color.R * 255)
	local g = math.floor(color.G * 255)
	local b = math.floor(color.B * 255)
	return string.format("#%02X%02X%02X", r, g, b)
end

-- create font tag
local function getFont(font)
	-- if font is Enum.Font convert it to string name
	if typeof(font) == "EnumItem" and font.EnumType == Enum.Font then
		font = font.Name
	end
	return `<font face="{font}">`
end

-- create color tag
local function getColor(color)
	-- convert Color3 to hex if needed
	if typeof(color) == "Color3" then
		color = toHex(color)
	end
	return `<font color="{color}">`
end

-- create size tag
local function getSize(size)
	return `<font size="{size}">`
end

-- create highlight tag
local function getMark(color)
	if typeof(color) == "Color3" then
		color = toHex(color)
	end
	return `<mark color="{color}">`
end

-- create stroke (outline) tag
local function getStroke(stroke)
	local color = stroke.Color or "#000000"
	if typeof(color) == "Color3" then
		color = toHex(color)
	end

	local thickness = stroke.Thickness or 1

	return `<stroke color="{color}" thickness="{thickness}">`
end

-- return style opening tag
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

-- return style closing tag
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

-- build gradient tags from multiple colors
local function getGradient(colors)
	local gradientTag = ""

	for _, color in ipairs(colors) do
		if typeof(color) == "Color3" then
			color = toHex(color)
		end

		gradientTag ..= `<font color="{color}">`
	end

	return gradientTag
end

-- ready themes you can use quickly
local Themes = {
	Error = { Color = "#FF0000", Font = "GothamBold", Style = "Bold", Size = 20 },
	Success = { Color = "#00FF00", Font = "Gotham", Style = "Italic", Size = 18 },
	Warning = { Color = "#FFFF00", Font = "Arial", Style = "Bold", Size = 19 },
}

-- get theme by name
local function getTheme(name)
	return Themes[name]
end

-- apply text transformations
local function applyTextTransform(word, data)
	if data.Uppercase then
		return string.upper(word)
	elseif data.SmallCaps then
		return string.upper(word)
	end

	return word
end

-- constructor (create new object)
function MainModule.new(text: string)
	local self = setmetatable({}, MainModule)

	-- store original text
	self.OriginalText = text

	-- split text into words
	self.Words = string.split(text, " ")

	return self
end

-- apply formatting to specific word index
function MainModule:Apply(indexes, data)
	-- apply style to one index
	local function applyToIndex(i)
		-- make sure index exists
		assert(self.Words[i], `Invalid word index: {i}`)

		-- add line break
		if data.LineBreak then
			self.Words[i] ..= "<br />"
			return
		end

		-- convert word into html comment
		if data.Comment then
			self.Words[i] = "<!-- " .. self.Words[i] .. " -->"
			return
		end

		local word = applyTextTransform(self.Words[i], data)

		local openTag = ""
		local closeTag = ""

		-- font
		if data.Font then
			openTag ..= getFont(data.Font)
			closeTag = "</font>" .. closeTag
		end

		-- color
		if data.Color then
			openTag ..= getColor(data.Color)
			closeTag = "</font>" .. closeTag
		end

		-- size
		if data.Size then
			openTag ..= getSize(data.Size)
			closeTag = "</font>" .. closeTag
		end

		-- style
		if data.Style then
			if data.Style == "Strikethrough" then
				openTag ..= "<s>"
				closeTag = "</s>" .. closeTag
			else
				openTag ..= getStyle(data.Style)
				closeTag = closeStyle(data.Style) .. closeTag
			end
		end

		-- stroke outline
		if data.Stroke then
			openTag ..= getStroke(data.Stroke)
			closeTag = "</stroke>" .. closeTag
		end

		-- highlight
		if data.Mark then
			openTag ..= getMark(data.Mark)
			closeTag = "</mark>" .. closeTag
		end

		-- text transparency
		if data.Transparency then
			openTag ..= `<font transparency="{data.Transparency}">`
			closeTag = "</font>" .. closeTag
		end

		-- shadow using stroke
		if data.Shadow then
			local shadowColor = data.Shadow.Color or "#000000"
			local offset = data.Shadow.Offset or 1

			openTag ..= `<stroke color="{shadowColor}" thickness="{offset}">`
			closeTag = "</stroke>" .. closeTag
		end

		-- gradient colors
		if data.Gradient then
			openTag ..= getGradient(data.Gradient)

			for _ = 1, #data.Gradient do
				closeTag = "</font>" .. closeTag
			end
		end

		-- apply tags
		self.Words[i] = openTag .. word .. closeTag
	end

	-- apply to multiple indexes
	if isTable(indexes) then
		for _, i in ipairs(indexes) do
			applyToIndex(i)
		end
	else
		applyToIndex(indexes)
	end
end

-- apply theme style
function MainModule:ApplyTheme(indexes, themeName)
	local theme = getTheme(themeName)
	self:Apply(indexes, theme)
end

-- quick function for font + color
function MainModule:ShortGenerate(indexes, font, color)
	self:Apply(indexes, { Font = font, Color = color })
end

-- rainbow effect per letter
function MainModule:Rainbow(indexes)
	local colors = {
		"#FF0000",
		"#FF7F00",
		"#FFFF00",
		"#00FF00",
		"#0000FF",
		"#4B0082",
		"#8B00FF",
	}

	local function applyRainbow(i)
		local word = self.Words[i]
		local result = ""

		for c = 1, #word do
			local letter = word:sub(c, c)
			local color = colors[(c - 1) % #colors + 1]

			result ..= `<font color="{color}">{letter}</font>`
		end

		self.Words[i] = result
	end

	if isTable(indexes) then
		for _, i in ipairs(indexes) do
			applyRainbow(i)
		end
	else
		applyRainbow(indexes)
	end
end

-- replace word in text
function MainModule:Replace(oldWord, newWord)
	for i, word in ipairs(self.Words) do
		if word == oldWord then
			self.Words[i] = newWord
		end
	end
end

-- remove all richtext tags from words
function MainModule:Clear(indexes)
	local function clearIndex(i)
		self.Words[i] = string.gsub(self.Words[i], "<.->", "")
	end

	if isTable(indexes) then
		for _, i in ipairs(indexes) do
			clearIndex(i)
		end
	else
		clearIndex(indexes)
	end
end

-- wrap word with custom function
function MainModule:Wrap(indexes, callback)
	local function wrapIndex(i)
		self.Words[i] = callback(self.Words[i])
	end

	if isTable(indexes) then
		for _, i in ipairs(indexes) do
			wrapIndex(i)
		end
	else
		wrapIndex(indexes)
	end
end

-- combine words back into full string
function MainModule:Build()
	return table.concat(self.Words, " ")
end

-- return module API
return {

	-- create new object
	New = function(text)
		return MainModule.new(text)
	end,

	-- export themes
	Themes = Themes,

	-- quick formatting helper
	Short = function(text, indexes, font, color)
		local obj = MainModule.new(text)

		obj:ShortGenerate(indexes, font, color)

		return obj:Build()
	end,
}
