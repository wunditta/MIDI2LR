--[[----------------------------------------------------------------------------

Presets.lua

Manages develop presets for plugin

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

local LrApplication = import 'LrApplication'
local LrTasks       = import 'LrTasks'
local LrDialogs     = import 'LrDialogs'
local LrView        = import 'LrView'
local LrUndo        = import 'LrUndo'
local LrDevelopController = import 'LrDevelopController'

local number_of_presets = 80
local currentpreset = {} -- [0] is for preset rotation of configured preset lists, [1]+ is for preset groups
local lastchange = 0
local lastphoto = nil
local lastaction = ''
local number_of_groups = 16
local number_of_multi = 6
local presetlimitreached = false
local presetresettimeout = 7

local function StartDialog(obstable,f)
  --populate table with presets
  for i = 1,number_of_presets do
    obstable['preset'..i] = {}
    obstable['preset'..i][1] = ProgramPreferences.Presets[i]
  end
  -- find presets stored in Lightroom and put in table name and UUID
  local psList = {}
  for _,fold in pairs(LrApplication.developPresetFolders()) do
    local foldname = fold:getName()
    for _,pst in pairs(fold:getDevelopPresets()) do
      psList[#psList+1] = {title = foldname..'\226\134\146'..pst:getName(), value = pst:getUuid()}
    end -- '\226\134\146' is right arrow in utf8
  end
  -- following variable set up number of rows and columns
  -- row*col must equal number_of_presets
  local group_rows, group_cols = 4,20
  local button_rows, button_cols = 4,20
  -- set up buttons on the right of the presets selection dialog
  local buttonpresets = {}
  for i = 1, button_cols do
    buttonpresets[i] = {
      spacing = f:control_spacing(),
      f:spacer { height = f:control_spacing() * 2},
    }
    for j = 1, button_rows do
      local k = button_rows * (i - 1) + j

      buttonpresets[i][#buttonpresets[i]+1] = f:push_button {fill_horizontal = 1, width_in_chars = 40, truncation = 'head',
        action = function() obstable['preset'..k] = nil end,
        title = LrView.bind { key = 'preset'..k,
          transform = function(value) return k..' '..(LrApplication.developPresetByUuid(value[1]):getName()) end
        },  -- title
      } -- push_button
    end
  end
  -- set up group boxes on left of selection dialog
  local grouppresets = {}
  for i = 1, group_cols do
    grouppresets[i] = {}
    for j = 1, group_rows do
      local k = group_rows * (i - 1) + j
      grouppresets[i][#grouppresets[i]+1] = f:simple_list {items = psList, allows_multiple_selection = false, value = LrView.bind ('preset'..k) }
    end
  end
  -- set up tabs
  local tabs = {}
  for i = 1,group_cols do
    local j = math.floor((i*group_rows-1)/button_rows)+1 --to determine which list of selected presets to include
    local label = (i-1)*group_rows+1 ..'-'..i*group_rows --must have space after 1 before ..
    tabs[i] = f:tab_view_item {title = label,
      identifier = 'tabview-'..label,
      f:row{
        f:column(grouppresets[i]),
        f:column(buttonpresets[j]) --for some reason, only shows in first group of each 'j' even though it is properly assigned
      } -- row
    } -- tabviewitem
  end
  return f:tab_view(tabs)
end

local function EndDialog(obstable, status)
  if status == 'ok' then
    ProgramPreferences.Presets = {} -- empty out prior settings
    for i = 1,number_of_presets do
      if type(obstable['preset'..i])=='table' then -- simple_list returns a table
        ProgramPreferences.Presets[i] = obstable['preset'..i][1]
      end
    end
  end
end

local function fApplyPreset(presetnumber)
  return function()
    local presetUuid = ProgramPreferences.Presets[presetnumber]
    if presetUuid == nil or LrApplication.activeCatalog():getTargetPhoto() == nil then return end
    local preset = LrApplication.developPresetByUuid(presetUuid)
    LrTasks.startAsyncTask ( function ()
      --[[-----------debug section, enable by adding - to beginning this line
      LrMobdebug.on()
      --]]-----------end debug section
        LrApplication.activeCatalog():withWriteAccessDo(
          'Apply preset '..preset:getName(),
          function()
            if ProgramPreferences.ClientShowBezelOnChange then
              LrDialogs.showBezel(preset:getName())
            end
            for _,photo in ipairs(LrApplication.activeCatalog():getTargetPhotos()) do
              --LrDialogs.message('getSetting='..tostring(LrDevelopController.getValue('Orientation')))
              --LrDialogs.message('getSetting='..tostring(photo:getDevelopSettings()['PerspectiveUpright']))
              --LrDialogs.message('getSetting='..tostring(photo:getDevelopSettings()['UprightFocalMode']))
              --LrDialogs.message('getSetting='..tostring(photo:getDevelopSettings()['UprightPreview']))
              --LrDialogs.message('getSetting='..tostring(photo:getDevelopSettings()['UprightVersion']))
              photo:applyDevelopPreset(preset)
            end
          end,
          { timeout = 4,
            callback = function() LrDialogs.showError(LOC("$$$/AgCustomMetadataRegistry/UpdateCatalog/Error=The catalog could not be updated with additional module metadata.")..'PastePreset.') end,
            asynchronous = true }
        )
    end )
  end
end

local function SetLastAction(param)
  -- Stores the last command locally; is called from Client.lua
  lastaction = param
end

local lastgrppresets = {} -- temporarily store the list of presets to cycle through to avoid generating the list again and again

local function AdvancePreset(pregrp, forward, multi)
  return function()
  if lastchange + 0.2 > os.clock() or pregrp == nil then
    return
  end
  local photo = LrApplication.activeCatalog():getTargetPhoto()
  if not photo then
    lastphoto = nil
    return
  end
  local adv = -1
  if forward then adv = 1 end
  local testpreset = 0
  local grouppresets = {}
  if photo ~= lastphoto then
    currentpreset = {}
    lastaction = ''
  end
  if lastchange + presetresettimeout < os.clock() then
    lastgrppresets = {}
  end
  if type(lastgrppresets[tostring(multi)..pregrp]) == 'table' then
    grouppresets = lastgrppresets[tostring(multi)..pregrp]
  else
    if pregrp == 0 then
      for i = 1, number_of_presets do
        if ProgramPreferences.Presets[i] then
          grouppresets[#grouppresets+1] = ProgramPreferences.Presets[i]
        end
      end
    else
      local grplist = {}
      if not multi then
        grplist[ProgramPreferences.PresetGroups[pregrp]] = true
      elseif multi=='multi' then
        for _,fold in ipairs(ProgramPreferences.PresetGroupsMulti[pregrp]) do
          grplist[fold] = true
        end
      end
      for _,fold in pairs(LrApplication.developPresetFolders()) do
        if grplist[fold:getPath()] or multi=='all' then
          for _,pre in pairs(fold:getDevelopPresets()) do
            grouppresets[#grouppresets+1] = pre:getUuid()
          end
        end
      end
    end
    lastgrppresets[tostring(multi)..pregrp] = grouppresets
  end
  local numpresets = #grouppresets
  if numpresets == 0 then return end
  if currentpreset[tostring(multi)..pregrp] == nil then
    testpreset = 1
    presetlimitreached = false
  else
    if presetlimitreached then
      testpreset = currentpreset[tostring(multi)..pregrp]
      presetlimitreached = false
    else
      testpreset = currentpreset[tostring(multi)..pregrp] + adv
      if testpreset > numpresets or testpreset < 1 then
        testpreset = currentpreset[tostring(multi)..pregrp]
        presetlimitreached = true
      end
    end
  end
  --if lastchange + presetresettimeout > os.clock() and LrUndo.canUndo() then
      -- in order to cycle through presets we have to undo the old one, but not if photo changed or time passed too long,
      -- because maybe there were done different operations after last preset, then undo would undo the wrong thing
      -- therefore a timeout for undo should help (far from good, but better than nothing)
  if (lastaction:sub(1,6)=='PreGrp' or lastaction=='PresetNext' or lastaction=='PresetPrevious') and LrUndo.canUndo() then
    LrUndo.undo()
  end
  lastchange = os.clock()
  lastphoto = photo
  currentpreset[tostring(multi)..pregrp] = testpreset
  --ApplyPresetUuID(grouppresets[testpreset], testpreset, numpresets)
  local presetUuid = grouppresets[testpreset]
  if presetUuid == nil or LrApplication.activeCatalog():getTargetPhoto() == nil then return end
  local preset = LrApplication.developPresetByUuid(presetUuid)
  LrTasks.startAsyncTask ( function ()
    --[[-----------debug section, enable by adding - to beginning this line
    LrMobdebug.on()
    --]]-----------end debug section
      LrApplication.activeCatalog():withWriteAccessDo(
        'Apply preset '..preset:getName(),
        function()
          if presetlimitreached then
            if ProgramPreferences.ClientShowBezelOnChange then
              LrDialogs.showBezel(LOC("$$$/MIDI2LR/PresetGroups/LimitReached=Limit reached, last preset undone, repeat to reapply"))
            end
          else
            if ProgramPreferences.ClientShowBezelOnChange then
              local postfix = ''
              if testpreset then postfix = tostring(testpreset) end
              if numpresets then postfix = postfix..'/'..tostring(numpresets) end
              if postfix ~= '' then postfix = ' ('..postfix..')' end
              LrDialogs.showBezel(preset:getName()..postfix)
            end
            LrApplication.activeCatalog():getTargetPhoto():applyDevelopPreset(preset)
          end
        end,
        { timeout = 4,
          callback = function() LrDialogs.showError(LOC("$$$/AgCustomMetadataRegistry/UpdateCatalog/Error=The catalog could not be updated with additional module metadata.")..'PastePreset.') end,
          asynchronous = true }
      )
  end )
  end
end

local function StartDialogGroups(obstable,f)
  --populate table with presets
  for i = 1,number_of_groups do
    obstable['pregrps'..i] = ProgramPreferences.PresetGroups[i]
  end
  for j=1, number_of_multi do
    if type(ProgramPreferences.PresetGroupsMulti[j]) ~= 'table' then ProgramPreferences.PresetGroupsMulti[j] = {} end
    for i = 1,number_of_groups do
      obstable['pregrpsmulti'..j..'-'..i] = ProgramPreferences.PresetGroupsMulti[j][i]
    end
  end
  local PresetGroupList = { { title='', value='' }, }
  for _,fold in pairs(LrApplication.developPresetFolders()) do
    PresetGroupList[#PresetGroupList+1] = {title = fold:getName(), value = fold:getPath()}
  end

  local dlgrows = {}
  local dlg = {}
  dlgrows[1] = f:static_text{title = LOC("$$$/MIDI2LR/PresetGroups/PresetGroups/Single=Single Preset Groups to cycle")}
  dlgrows[2] = f:separator {fill_horizontal = 1}
  dlgrows[3] = f:spacer {height = 10}
  for i=1, number_of_groups do
    dlgrows[i+3] = f:row{
      bind_to_object = obstable, -- default bound table
      f:static_text{title = LOC("$$$/MIDI2LR/PresetGroups/PresetGroups/Short=Preset Group").." "..i,
        width = LrView.share('preset_groups_label')},
      f:popup_menu{
        items = PresetGroupList,
        value = LrView.bind('pregrps'..i),
      }
    }
  end
  dlg = {f:column(dlgrows), f:spacer{width=10}, f:column{f:separator{fill_vertical=1}}, f:spacer{width=10}}
  for j=1, number_of_multi do
    dlgrows = {}
    dlgrows[1] = f:static_text{title = LOC("$$$/MIDI2LR/PresetGroups/PresetGroups/Multi=Multi PG")..' '..j}
    dlgrows[2] = f:separator {fill_horizontal = 1}
    dlgrows[3] = f:spacer {height = 10}
    for i=1, number_of_groups do
      dlgrows[i+3] = f:popup_menu{
        bind_to_object = obstable, -- default bound table
        items = PresetGroupList,
        value = LrView.bind('pregrpsmulti'..j..'-'..i),
        width = 100,
      }
    end
    dlg[#dlg+1] = f:column(dlgrows)
    dlg[#dlg+1] = f:spacer{width=5}
    dlg[#dlg+1] = f:column{f:separator{fill_vertical=1}}
    dlg[#dlg+1] = f:spacer{width=5}
  end
  --[[
  local dlgrowsmulti = {}
    for i=numdiv2 + 1, number_of_groups do
    dlgrows1[i - numdiv2] = f:row{
      bind_to_object = obstable, -- default bound table
      f:static_text{title = LOC("$$$/MIDI2LR/PresetGroups/PresetGroup=Develop Preset Group").." "..i,
        width = LrView.share('preset_groups_label')},
      f:popup_menu{
        items = PresetGroupList,
        value = LrView.bind('pregrps'..i)
      }
    }
  end
  --]]
  --return f:row{f:column(dlgrows),f:column(dlgrows1)}
  return f:column{ f:row(dlg), f:spacer{height=20},
    f:static_text{title = LOC("$$$/MIDI2LR/PresetGroups/PresetGroups/Desc/Single=If one of the single groups are assigned to a control, all presets within this one group are cycled.")},
    f:static_text{title = LOC("$$$/MIDI2LR/PresetGroups/PresetGroups/Desc/Multi=If one of the multi groups are assigned to a control, all presets of all groups specified in the column are cycled.")},
    f:static_text{title = LOC("$$$/MIDI2LR/PresetGroups/PresetGroups/Desc/All=There are also functions for cycling all presets of all groups.")},
  }
end

local function EndDialogGroups(obstable, status)
  if status == 'ok' then
    ProgramPreferences.PresetGroups = {} -- empty out prior settings
    for i = 1,number_of_groups do
      ProgramPreferences.PresetGroups[i] = obstable['pregrps'..i]
    end
    ProgramPreferences.PresetGroupsMulti = {} -- empty out prior settings
    for j=1, number_of_multi do
      ProgramPreferences.PresetGroupsMulti[j] = {}
      for i = 1,number_of_groups do
        ProgramPreferences.PresetGroupsMulti[j][i] = obstable['pregrpsmulti'..j..'-'..i]
      end
    end
  end
end

return {
  StartDialog = StartDialog,
  EndDialog = EndDialog,
  NextPreset = NextPreset,
  PreviousPreset = PreviousPreset,
  AdvancePreset = AdvancePreset,
  SetLastAction = SetLastAction,
  fAdvancePreset = fAdvancePreset,
  fApplyPreset = fApplyPreset,
  StartDialogGroups = StartDialogGroups,
  EndDialogGroups = EndDialogGroups,
}
