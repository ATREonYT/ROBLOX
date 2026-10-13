-- Approximate visual targets. Calibrate against reference/approved-ui.png in Studio.
local Theme = {
 Colors = {
  Panel = Color3.fromRGB(37,61,89), Header = Color3.fromRGB(131,99,196),
  InactiveTab = Color3.fromRGB(48,70,109), SelectedTab = Color3.fromRGB(248,197,110),
  Action = Color3.fromRGB(140,136,204), ActionHover = Color3.fromRGB(156,153,219),
  ActionPressed = Color3.fromRGB(119,115,181), Disabled = Color3.fromRGB(102,114,142),
  Text = Color3.fromRGB(244,243,250), DarkText = Color3.fromRGB(24,37,66),
  Border = Color3.fromRGB(83,105,133), SelectedBorder = Color3.fromRGB(242,203,105),
  Close = Color3.fromRGB(216,43,87), Progress = Color3.fromRGB(244,196,95),
 },
 Font = Enum.Font.Gotham,
 BoldFont = Enum.Font.GothamBold,
 PanelTransparency = 0.20,
 HeaderTransparency = 0.05,
 Spacing = { Small = 4, Medium = 8, Large = 12, Outer = 16 },
 Motion = { Hover = 0.10, Press = 0.07, Open = 0.20, Close = 0.14 },
}
return Theme
