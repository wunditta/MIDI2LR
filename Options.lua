--[[----------------------------------------------------------------------------

Options.lua

Manages options for plugin

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

local ActionSeries      = require 'ActionSeries'
local Filters           = require 'Filters'
local Keys              = require 'Keys'
local Limits            = require 'Limits'
local LocalPresets      = require 'LocalPresets'
local OU                = require 'OptionsUtilities'
local Preferences       = require 'Preferences'
local Profiles          = require 'Profiles'
local Presets           = require 'Presets'
local CopySettings      = require 'CopySettings'
local Init              = require 'Init'
local LrBinding         = import 'LrBinding'
local LrDialogs         = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrView            = import 'LrView'
--[[-----------debug section, enable by adding - to beginning this line
local LrMobdebug = import 'LrMobdebug'
--]]-----------end debug section

local function setOptions()
  LrFunctionContext.callWithContext( "assignPresets", function( context )
      --[[-----------debug section, enable by adding - to beginning this line
      LrMobdebug.on()
      --]]-----------end debug section
      local f = LrView.osFactory()
      local properties = LrBinding.makePropertyTable( context )
      local OptLimits = Init.OptionLimits
      --following not managed by another module
      -- See Init.lua for default values!!!
      properties.ClientShowBezelOnChange = ProgramPreferences.ClientShowBezelOnChange
      properties.TrackingDelay = ProgramPreferences.TrackingDelay
      properties.RevealAdjustedControls = ProgramPreferences.RevealAdjustedControls
      --properties.DeleteAnyhow = ProgramPreferences.DeleteAnyhow
      properties.FineEnabled = ProgramPreferences.FineEnabled
      properties.RememberSelection = ProgramPreferences.RememberSelection
      properties.FineMagnify = ProgramPreferences.FineMagnify
      properties.FineAutoSensitivity = ProgramPreferences.FineAutoSensitivity
      properties.FineDeactivate = ProgramPreferences.FineDeactivate

      -- assemble dialog box contents
      local contents =
      f:view{
        bind_to_object = properties, -- default bound table
        f:tab_view {
          f:tab_view_item{
            title = LOC("$$$/CRaw/Style/ProfileGroup/Profiles=Profile"),
            identifier = 'profiles',
            Profiles.StartDialog(properties,f),
          },
          f:tab_view_item{
            title = LOC("$$$/Library/Filter/FilterLabel=Library filter"):gsub(' ?:',''),
            identifier = 'filters',
            Filters.StartDialog(properties,f),
          },
          f:tab_view_item {
            title = LOC("$$$/MIDI2LR/Options/ShortcutsMisc=Keyboard shortcuts"),
            identifier = 'keys',
            Keys.StartDialog(properties,f),
          }, -- tab_view_item
          f:tab_view_item {
            title = LOC("$$$/MIDI2LR/Shortcuts/SeriesofCommands=Series of commands"),
            identifier = 'commandseries',
            ActionSeries.StartDialog(properties,f),
          }, --tab_view_item
          f:tab_view_item {
            title = LOC("$$$/MIDI2LR/LocalPresets/Presets=Local adjustments presets"),
            identifier = 'localpresets',
            LocalPresets.StartDialog(properties,f),
          }, --tab_view_item
          f:tab_view_item {
            title = LOC("$$$/MIDI2LR/CopyPresets/CopyPresets=Copy Develop Setting Presets"),
            identifier = 'copypresets',
            CopySettings.StartDialog(properties,f),
          }, --tab_view_item
          f:tab_view_item {
            title = LOC("$$$/LibraryMetadata/IPTCEx/Others=Others"),
            identifier = 'othersettings',
            f:column {
              Limits.StartDialog(properties,f),
              --f:separator {fill_horizontal = 0.9},
              f:spacer { height = 10},
              f:group_box {
                title = LOC("$$$/LibraryMetadata/IPTCEx/Others=Others"),
                f:row {
                  f:checkbox {title = LOC("$$$/AgDocument/ModulePicker/Settings/ShowStatusAndActivity=Show status and activity"), value = LrView.bind('ClientShowBezelOnChange')},
                  f:checkbox {title = LOC("$$$/MIDI2LR/Options/RevealAdjustedControls=Reveal adjusted controls"), value = LrView.bind('RevealAdjustedControls')},
                  f:spacer {width = 20},
                  OU.slider(f,properties,LOC("$$$/MIDI2LR/Options/TrackingDelay=Tracking Delay"),'slidersets','TrackingDelay',0,3,2),
                  --f:checkbox {title = LOC("$$$/AgLibrary/Trash/NoTrash/DeleteAnyhow=Delete Files permanently"), value = LrView.bind('DeleteAnyhow')},
                }, -- row
                f:row {
                  f:checkbox {title = LOC("$$$/MIDI2LR/Options/RememberSel=Remember Selection for each folder"), value = LrView.bind('RememberSelection')},
                }, -- row
              --f:separator {fill_horizontal = 0.9},
              }, -- group_box
              f:spacer { height = 10},
              f:group_box {
                title = LOC("$$$/MIDI2LR/Finetune/Title=Fine-tuning"),
                f:checkbox {title = LOC("$$$/MIDI2LR/Finetune/Enable=Enable Fine-tuning"), value = LrView.bind('FineEnabled')},
                OU.slider(f,properties,LOC("$$$/MIDI2LR/Finetune/Magnify=Movement Magnification"),'','FineMagnify',1,10,OptLimits.FineMagnify),
                OU.slider(f,properties,LOC("$$$/MIDI2LR/Finetune/AutoSensitivity=Auto-activate Sensitivity (0=disable)"),'','FineAutoSensitivity',0,20,OptLimits.FineAutoSensitivity),
                OU.slider(f,properties,LOC("$$$/MIDI2LR/Finetune/AutoTimeout=Deactivation Timeout (0=disable)"),'','FineDeactivate',0,10,OptLimits.FineDeactivate,true),
              }, -- group_box
            }, -- column
          }, -- tab_view_item
        }, -- tab_view
      } -- view

      -- display dialog
      local result = LrDialogs.presentModalDialog {
        title = LOC('$$$/MIDI2LR/Options/dlgtitle=Set MIDI2LR options'),
        contents = contents,
      }
      ActionSeries.EndDialog(properties,result)
      Filters.EndDialog(properties,result)
      Keys.EndDialog(properties,result)
      Limits.EndDialog(properties,result)
      LocalPresets.EndDialog(properties,result)
      Profiles.EndDialog(properties,result)
      Presets.EndDialogGroups(properties,result)
      CopySettings.EndDialog(properties,result)
      if result == 'ok' then
        local LrDevelopController = import 'LrDevelopController'
        --following not managed by another lua module file
        ProgramPreferences.ClientShowBezelOnChange = properties.ClientShowBezelOnChange
        ProgramPreferences.TrackingDelay = properties.TrackingDelay
        if ProgramPreferences.TrackingDelay ~= nil then
          LrDevelopController.setTrackingDelay(ProgramPreferences.TrackingDelay)
        end

        if ProgramPreferences.RevealAdjustedControls ~= properties.RevealAdjustedControls then
          ProgramPreferences.RevealAdjustedControls = properties.RevealAdjustedControls
          LrDevelopController.revealAdjustedControls(ProgramPreferences.RevealAdjustedControls)
        end
        --ProgramPreferences.DeleteAnyhow = properties.DeleteAnyhow
        ProgramPreferences.RememberSelection = properties.RememberSelection
        ProgramPreferences.FineEnabled = properties.FineEnabled
        ProgramPreferences.FineMagnify = properties.FineMagnify
        ProgramPreferences.FineAutoSensitivity = properties.FineAutoSensitivity
        ProgramPreferences.FineDeactivate = properties.FineDeactivate

        --then save preferences
        Preferences.Save()
      end -- if result ok
      -- finished with assigning values from dialog
    end
  )
end

setOptions() --execute
