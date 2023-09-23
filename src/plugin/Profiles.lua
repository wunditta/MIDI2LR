--[[----------------------------------------------------------------------------

Profiles.lua

Manages profile changes for plugin

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

local Database            = require 'Database'
local Init                = require 'Init'
local Limits              = require 'Limits'
local ProfileTypes        = require 'ProfileTypes'
local LrApplication       = import 'LrApplication'
local LrApplicationView   = import 'LrApplicationView'
local LrDevelopController = import 'LrDevelopController'
local LrDialogs           = import 'LrDialogs'
local LrFileUtils         = import 'LrFileUtils'
local LrStringUtils       = import 'LrStringUtils'
local LrTasks             = import 'LrTasks'
local LrView              = import 'LrView'
local LrSelection         = import 'LrSelection'

local currentTMP = {Tool = '', Module = '', Panel = '', Profile = ''}
local loadedprofile = ''-- according to application and us
local profilepath = '' --according to application

local function CropSideOriented(side_unoriented, orientation)
  --local cropside = {CropTop = "CropTop", CropLeft = "CropLeft", CropBottom = "CropBottom", CropRight = "CropRight", vert = "CropMoveVertical", hor = "CropMoveHorizontal"}
  local cropside = { "CropTop", "CropLeft", "CropBottom", "CropRight", "CropTopLeft", "CropBottomLeft", "CropBottomRight", "CropTopRight", "CropMoveVertical", "CropMoveHorizontal" }
  if orientation == 'AB' or orientation == nil then return side_unoriented, cropside end
  local rotations = { BC = 1, CD = 2, DA = 3 }
  local itemnum = 0
  for i,item in ipairs(cropside) do
    if item == side_unoriented then itemnum = i end
  end
  local rot = rotations[orientation]
  if itemnum == 0 or rot == nil then return side_unoriented, cropside end
  for _=1,rot do
    table.insert( cropside, 5, cropside[1] )
    table.remove( cropside, 1 )
    table.insert( cropside, 9, cropside[5] )
    table.remove( cropside, 5 )
    --cropside['temp'] = cropside['CropTop']
    --cropside['CropTop'] = cropside['CropLeft']
    --cropside['CropLeft'] = cropside['CropBottom']
    --cropside['CropBottom'] = cropside['CropRight']
    --cropside['CropRight'] = cropside['temp']
  end
  if orientation == 'BC' or orientation == 'DA' then
    --cropside['temp'] = cropside['vert']
    --cropside['vert'] = cropside['hor']
    --cropside['hor'] = cropside['temp']
    table.insert( cropside, 11, cropside[9] )
    table.remove( cropside, 9 )
  end
  --return cropside[side_unoriented]
  return cropside[itemnum], cropside
end

local function CropSideRev(value, side_oriented, orientation)
  if (side_oriented=='CropLeft' or side_oriented=='CropRight') and (orientation == 'CD' or orientation == 'BC') then value = 1 - value end
  if (side_oriented=='CropTop' or side_oriented=='CropBottom') and (orientation == 'AB'or orientation == 'BC') then value = 1 - value end
  return value
end

--Some of these functions are also needed in Client and ClientUtilities (Profiles is already imported to both)
local function getSplitIndex(val0to1, numsubdiv)
  -- A value 0..1 (val0to1) is converted to an index (the n-th subdivision; starting with 1) depending of the total number of subdivisions (numsubdiv)
  return math.min(numsubdiv, math.floor((tonumber(val0to1)*numsubdiv) + 1))
end

local function getSplitValue0to1(index, numsubdiv)
  -- An index (1 to numsubdiv) is converted to a floating value 0..1, whereas the value is in the center of the specified subdivision range
  if index == nil then return nil end
  return math.floor(((index - 0.5) / numsubdiv * 100) + 0.5) / 100
end

local function ReverseTables(tables)
  -- Prepares two tables out of a simple array (e.g. SetColorlabel) for VariableMove parameters (see below), i.e. where a slider can be used to choose one of the options
  -- origtab is an array with two elements: [1] just an indexed table of the array, [2] the number of elements
  -- revtab is an array with two elements: [1] the reversed table above, i.e. key and value exchanged (e.g. red = 2), [2] the number of elements
  local origtab = {}
  local revtab = {}
  local total = 0
  for t1name,t1 in pairs(tables) do -- or ipairs?
    t1 = t1.values
    origtab[t1name] = { [1] = t1 }
    revtab[t1name] = { [1] = {} }
    total = 0
    for idx,t2 in pairs(t1) do -- or ipairs?
      revtab[t1name][1][t2]=idx
      total = total + 1
    end
    origtab[t1name][2] = total
    revtab[t1name][2] = total
  end
  return revtab, origtab
end

local VariableMoveDB = {
  SetColorlabel   = { values = { 'none', 'red', 'yellow', 'green', 'blue', 'purple' },
                      getvalf = function() return LrSelection.getColorLabel() end,
                      setvalf = function(value) LrSelection.setColorLabel(value) end,
                      bezel = LOC("$$$/AgDevelop/Toolbar/Tooltip/SetColorLabel=Set Color Label"),
                    },
  SetRating       = { values = { 0, 1, 2, 3, 4, 5 },
                      getvalf = function() return LrSelection.getRating() end,
                      setvalf = function(value) LrSelection.setRating(value) end,
                      bezel = '', -- Lr shows the new setting for this; was: LOC("$$$/AgDevelop/Toolbar/Tooltip/SetRating=Set Rating")
                    },
  SetFlag         = { values = { -1, 0, 1 },
                      getvalf = function() return LrSelection.getFlag() end,
                      setvalf = function(value)
                                  if value==-1 then LrSelection.flagAsReject()
                                  elseif value==0 then LrSelection.removeFlag()
                                  elseif value==1 then LrSelection.flagAsPick()
                                  end
                                end,
                      bezel = '', -- Lr shows the new setting for this; was: LOC("$$$/AgDevelop/Toolbar/Tooltip/SetRating=Set Rating")
                    },
}
local VariableMoveTableRev, VariableMoveTable = ReverseTables(VariableMoveDB)
local VariableMoveLastValue = {}

local function UpdateVariableMove(force)
-- Updates MIDI when a VariableMove setting changed
-- The commands must be defined in Database.lua as type "variablemove", in addition to the table "VariableMoveDB" above
  local currentvalue
  for _,param in ipairs(Database.VariableMove) do
  --for param in pairs(Database.VariableMove) do
    currentvalue = VariableMoveDB[param].getvalf()
    if (VariableMoveLastValue[param] ~= currentvalue or force) and currentvalue ~= nil then
      MIDI2LR.SERVER:send(string.format('%s %g\n', param, getSplitValue0to1(VariableMoveTableRev[param][1][currentvalue], VariableMoveTableRev[param][2])))
      VariableMoveLastValue[param] = currentvalue
    end
  end
end

local function SetVariableMove(value, param)
-- Updates Lr when a MIDI value changes
  local newvalue = VariableMoveTable[param][1][getSplitIndex(value, VariableMoveTable[param][2])]
  if newvalue ~= VariableMoveDB[param]['getvalf']() then
    VariableMoveDB[param].setvalf(newvalue)
    VariableMoveLastValue[param] = newvalue
    if ProgramPreferences.ClientShowBezelOnChange and VariableMoveDB[param].bezel ~= '' then
      LrTasks.startAsyncTask( function()
        LrDialogs.showBezel(VariableMoveDB[param].bezel..': '..tostring(newvalue):gsub("^%l", string.upper))
      end )
    end
  end
end


local function doprofilechange(newprofile)
-- Sets all controllers on device to correct settings after a new profile was loaded to the application
-- !!!!!!!!!!!!!!!!!!! Similar code exists in Client.AdjustmentChangeObserver  and ClientUtilities.FullRefresh and has to be changed accordingly !!!!!!!!!!!!!!!!!!!
  if ProgramPreferences.ProfilesShowBezelOnChange then
    local filename = newprofile:match(".-([^\\^/]-([^%.]+))$")
    filename = filename:sub(0, -5)
    LrDialogs.showBezel(filename)
  end
  loadedprofile = newprofile
  if   (LrApplication.activeCatalog():getTargetPhoto() ~= nil) and
  (LrApplicationView.getCurrentModuleName() == 'develop') then
    -- refresh MIDI controller since mapping has changed
    LrTasks.startAsyncTask ( function ()
            --[[-----------debug section, enable by adding - to beginning this line
    LrMobdebug.on()
    --]]-----------end debug section
        local photoval = LrApplication.activeCatalog():getTargetPhoto():getDevelopSettings()
        -- refresh crop values
        --local val_bottom = photoval.CropBottom
        --local val_bottom = CropSideRev(photoval[CropSideOriented('CropBottom', photoval.orientation)], photoval.orientation)
        --local param_top, param_left, param_bottom, param_right = table.unpack(select(2, CropSideOriented('CropTop', photoval.orientation)))
        local _, params = CropSideOriented('CropTop', photoval.orientation)
        local param_top, param_left, param_bottom, param_right = params[1], params[2], params[3], params[4]
        local val_bottom = CropSideRev(photoval[param_bottom], param_bottom, photoval.orientation)
        MIDI2LR.SERVER:send(string.format('CropBottomRight %g\n', val_bottom))
        MIDI2LR.SERVER:send(string.format('CropBottomLeft %g\n', val_bottom))
        MIDI2LR.SERVER:send(string.format('CropAll %g\n', val_bottom))
        MIDI2LR.SERVER:send(string.format('CropBottom %g\n', val_bottom))
        --local val_top = photoval.CropTop
        --local val_top = CropSideRev(photoval[CropSideOriented('CropTop', photoval.orientation)], photoval.orientation)
        local val_top = CropSideRev(photoval[param_top], param_top, photoval.orientation)
        MIDI2LR.SERVER:send(string.format('CropTopRight %g\n', val_top))
        MIDI2LR.SERVER:send(string.format('CropTopLeft %g\n', val_top))
        MIDI2LR.SERVER:send(string.format('CropTop %g\n', val_top))
        --local val_left = photoval.CropLeft
        --local val_right = photoval.CropRight
        --local val_left = CropSideRev(photoval[CropSideOriented('CropLeft', photoval.orientation)], photoval.orientation)
        --local val_right = CropSideRev(photoval[CropSideOriented('CropRight', photoval.orientation)], photoval.orientation)
        local val_left = CropSideRev(photoval[param_left], param_left, photoval.orientation)
        local val_right = CropSideRev(photoval[param_right], param_right, photoval.orientation)
        MIDI2LR.SERVER:send(string.format('CropLeft %g\n', val_left))
        MIDI2LR.SERVER:send(string.format('CropRight %g\n', val_right))
        local range_v = (1 - (val_bottom - val_top))
        if range_v == 0.0 then
          MIDI2LR.SERVER:send('CropMoveVertical 0\n')
        else
          MIDI2LR.SERVER:send(string.format('CropMoveVertical %g\n', val_top / range_v))
        end
        local range_h = (1 - (val_right - val_left))
        if range_h == 0.0 then
          MIDI2LR.SERVER:send('CropMoveHorizontal 0\n')
        else
          MIDI2LR.SERVER:send(string.format('CropMoveHorizontal %g\n', val_left / range_h))
        end
        for param,altparam in pairs(Database.Parameters) do
          if param:sub(1,4) ~= 'Crop' then
            local min,max = Limits.GetMinMax(param) --can't include ClientUtilities: circular reference
            local lrvalue
            if altparam == 'Direct' then
              if LrDevelopController.getSelectedMask() then lrvalue = LrDevelopController.getValue(param) end
            else
              if param == altparam then
                lrvalue = (photoval[param] or 0)
              else
                lrvalue = (photoval[param] or 0) + (photoval[altparam] or 0)
              end
            end
            if type(min) == 'number' and type(max) == 'number' and type(lrvalue) == 'number' then
              local midivalue = (lrvalue-min)/(max-min)
              if midivalue >= 1.0 then
                MIDI2LR.SERVER:send(string.format('%s 1.0\n', param))
              elseif midivalue <= 0.0 then -- = catches -0.0 and sends it as 0.0
                MIDI2LR.SERVER:send(string.format('%s 0.0\n', param))
              else
                MIDI2LR.SERVER:send(string.format('%s %g\n', param, midivalue))
              end
            end
          end
        end
      end
    )
  end
  LrTasks.startAsyncTask ( function ()
    UpdateVariableMove(true)
  end )
end

local function setDirectory(value)
  profilepath = value
end

local function setFile(value)
  if loadedprofile ~= value then
    doprofilechange(value)
  end
end

local function setFullPath(value)
  local path, profile = value:match("(.-)([^\\/]-%.?([^%.\\/]*))$")
  profilepath = path
  if profile ~= loadedprofile then
    doprofilechange(profile)
  end
end

local function changeProfile(profilename, ignoreCurrent)
  local changed = false
  if profilename and ProfileTypes[profilename] then
    local newprofile_file = ProgramPreferences.Profiles[profilename]
    local TMP = ProfileTypes[profilename]['TMP']
    if (newprofile_file ~= nil) and (newprofile_file ~= '') and (loadedprofile ~= newprofile_file) and
    ((ignoreCurrent == true) or (currentTMP[TMP] ~= profilename)) then
      MIDI2LR.SERVER:send('SwitchProfile '..newprofile_file..'\n')
      doprofilechange(newprofile_file)
      changed = true
    end
    currentTMP[TMP] = profilename
  end
  return changed
end

local function checkProfile()
  --as this runs 4X/second, doing check against currentTMP here to
  -- make it faster than always deferring to changeProfile
  local newmod = LrApplicationView.getCurrentModuleName()
  if newmod == 'develop' then
    local tool = LrDevelopController.getSelectedTool()
    if currentTMP.Module ~= newmod and
    ProgramPreferences.Profiles[tool] == '' then
      changeProfile(newmod)
    elseif currentTMP.Tool ~= tool then
      changeProfile(tool)
      currentTMP.Module = newmod  -- make sure that TMP.Module is
      -- set correctly when changing to tool profile
    end
  elseif currentTMP.Module ~= newmod then
    changeProfile(newmod)
    currentTMP.Tool = '' -- remove tool for modules~=develop
  end
end

local function StartDialog(obstable,f)
  for k in pairs(ProfileTypes) do
    obstable['Profile'..k] = ProgramPreferences.Profiles[k]
  end
  obstable.ProfilesShowBezelOnChange = ProgramPreferences.ProfilesShowBezelOnChange
  local completion = {}
  local auto_completion = false
  if profilepath and profilepath ~= '' then
    auto_completion = true
    for filePath in LrFileUtils.files(profilepath) do
      local _, fn, ext = filePath:match("(.-)([^\\/]-%.?([^%.\\/]*))$")
      if ext == 'xml' then
        completion[#completion+1] = fn
      end
    end
  end
  local allboxes =
  f:column{
    spacing = f:control_spacing(),
    f:row {
      f:column {
        width = LrView.share('profile_column'),
        f:group_box {
          title = LOC("$$$/Application/Menu/Window/Modules=Modules:"):gsub(' ?:',''), --string has : in it in LR database
          width = LrView.share('profile_group'),
          font='<system/small/bold>',
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.library.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profilelibrary'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.develop.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profiledevelop'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.map.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profilemap'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.book.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profilebook'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.slideshow.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileslideshow'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.print.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprint'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.web.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileweb'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
        },
        f:spacer { height=11 },
        f:group_box {
          title = LOC("$$$/AgDevelop/Menu/Tools=Tools"):gsub('&',''), --string has & in it in LR database
          width = LrView.share('profile_group'),
          font='<system/small/bold>',
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.loupe.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileloupe'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.crop.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profilecrop'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.dust.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profiledust'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.redeye.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileredeye'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.masking.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profilemasking'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:spacer{height = f:control_spacing() * 4,},
          f:push_button {title = LOC("$$$/AgDevelop/PresetsPanel/ClearAll=Clear All"), action = function()
              for k in obstable:pairs() do
                if k:find('Profile') == 1 then
                  obstable[k] = ''
                end
              end
            end
          },
          f:checkbox {title = LOC("$$$/MIDI2LR/Profiles/NotifyWhenChanged=Notify when profile changes"), value = LrView.bind('ProfilesShowBezelOnChange')}
        },
      },
      f:spacer { width = 2 },
      f:column {
        width = LrView.share('profile_column'),
        f:group_box {
          title = LOC("$$$/AgPreferences/Interface/GroupTitle/Panels=Panels"),
          width = LrView.share('profile_group'),
          size='regular', font='<system/small/bold>',
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.adjustPanel.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('ProfileadjustPanel'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.tonePanel.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('ProfiletonePanel'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.mixerPanel.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('ProfilemixerPanel'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.colorGradingPanel.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('ProfilecolorGradingPanel'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.detailPanel.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('ProfiledetailPanel'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.lensCorrectionsPanel.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('ProfilelensCorrectionsPanel'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.transformPanel.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('ProfiletransformPanel'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.effectsPanel.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('ProfileeffectsPanel'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.calibratePanel.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('ProfilecalibratePanel'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
        },
        f:spacer { height=11 },
        f:group_box {
          title = LOC("$$$/CRaw/Style/ProfileGroup/Profiles=Profiles"),
          width = LrView.share('profile_group'),
          size='regular', font='<system/small/bold>',
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile1.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile1'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile2.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile2'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile3.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile3'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile4.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile4'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile5.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile5'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile6.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile6'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile7.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile7'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile8.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile8'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
        },
      },
      f:spacer { width = 2 },
      f:column {
        width = LrView.share('profile_column'),
        f:group_box {
          title = LOC("$$$/CRaw/Style/ProfileGroup/Profiles=Profiles"),
          width = LrView.share('profile_group'),
          font='<system/small/bold>',
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile9.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile9'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile10.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile10'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile11.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile11'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile12.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile12'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile13.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile13'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile14.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile14'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile15.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile15'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile16.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile16'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile17.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile17'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile18.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile18'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile19.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile19'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile20.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile20'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile21.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile21'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile22.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile22'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile23.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile23'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile24.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile24'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile25.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile25'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
          f:row {
            font='<system>',
            f:static_text{title = ProfileTypes.profile26.friendlyName, width = LrView.share('profile_label'),},
            f:edit_field{ value = LrView.bind ('Profileprofile26'), width = LrView.share('profile_value'),
              width_in_chars = 15, auto_completion = auto_completion, completion = completion},
          },
        },
      },
    },

  }
  return allboxes
end

local function EndDialog(obstable, status)
  if status == 'ok' then
    Init.UseDefaultsProfiles() -- empty out prior settings
    for k in pairs(ProfileTypes) do
      if type(obstable['Profile'..k])=='string' then
        ProgramPreferences.Profiles[k] = LrStringUtils.trimWhitespace(obstable['Profile'..k])
      end
    end
    ProgramPreferences.ProfilesShowBezelOnChange = obstable.ProfilesShowBezelOnChange
  end
end

return {
  changeProfile = changeProfile,
  checkProfile = checkProfile,
  StartDialog = StartDialog,
  EndDialog = EndDialog,
  setDirectory = setDirectory,
  setFile = setFile,
  setFullPath = setFullPath,
  CropSideOriented = CropSideOriented,
  CropSideRev = CropSideRev,
  UpdateVariableMove = UpdateVariableMove,
  SetVariableMove = SetVariableMove,
}
