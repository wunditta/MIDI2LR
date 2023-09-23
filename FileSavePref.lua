--[[ 

FileSavePref.lua
Saves application preferences to a file
 
This file is part of MIDI2LR. Copyright 2015 by Rory Jaffe.

MIDI2LR is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later version.

MIDI2LR is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
MIDI2LR.  If not, see <http://www.gnu.org/licenses/>. 
------------------------------------------------------------------------------]]

local Preferences = require 'Preferences'
local LrDialogs   = import 'LrDialogs'

local savelocation = LrDialogs.runSavePanel({title=LOC("$$$/MIDI2LR/Menu/ExportConfiguration=&Export configuration"):gsub('%(%&%a%)',''):gsub('%&',''),requiredFileType="txt",canCreateDirectories=true})

if type(savelocation) == 'string' then
  Preferences.Save(savelocation)
end