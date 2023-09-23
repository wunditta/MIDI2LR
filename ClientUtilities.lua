--[[----------------------------------------------------------------------------

ClientUtilities.lua

Procedures used by Client.lua. Moved to separate file as size of Client.lua
became unwieldy.

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

local Limits     = require 'Limits'
local Database   = require 'Database'
local Profiles   = require 'Profiles'
local LrApplication       = import 'LrApplication'
local LrApplicationView   = import 'LrApplicationView'
local LrDevelopController = import 'LrDevelopController'
local LrDialogs           = import 'LrDialogs'
local LrLocalization      = import 'LrLocalization'
local LrStringUtils       = import 'LrStringUtils'
local LrTasks             = import 'LrTasks'
local LrSelection         = import 'LrSelection'

--modules may be library develop map book slideshow print web
local needsModule = {
  [LrDevelopController.addAdjustmentChangeObserver]    = {module = 'develop', photoSelected = false },
  [LrDevelopController.addToCurrentMask]               = {module = 'develop', photoSelected = true },
  [LrDevelopController.createNewMask]                  = {module = 'develop', photoSelected = true },
  [LrDevelopController.decrement]                      = {module = 'develop', photoSelected = true },
  [LrDevelopController.getProcessVersion]              = {module = 'develop', photoSelected = true },
  [LrDevelopController.getRange]                       = {module = 'develop', photoSelected = true },
  [LrDevelopController.getSelectedTool]                = {module = 'develop', photoSelected = false },
  [LrDevelopController.getValue]                       = {module = 'develop', photoSelected = true },
  [LrDevelopController.increment]                      = {module = 'develop', photoSelected = true },
  [LrDevelopController.intersectWithCurrentMask]       = {module = 'develop', photoSelected = true },
  [LrDevelopController.resetAllDevelopAdjustments]     = {module = 'develop', photoSelected = true },
  [LrDevelopController.resetCrop]                      = {module = 'develop', photoSelected = true },
  [LrDevelopController.resetMasking]                   = {module = 'develop', photoSelected = true },
  [LrDevelopController.resetRedeye]                    = {module = 'develop', photoSelected = true },
  [LrDevelopController.resetSpotRemoval]               = {module = 'develop', photoSelected = true },
  [LrDevelopController.resetToDefault]                 = {module = 'develop', photoSelected = true },
  [LrDevelopController.resetTransforms]                = {module = 'develop', photoSelected = true },
  [LrDevelopController.revealAdjustedControls]         = {module = 'develop', photoSelected = false },
  [LrDevelopController.revealPanel]                    = {module = 'develop', photoSelected = false },
  [LrDevelopController.selectTool]                     = {module = 'develop', photoSelected = false },
  [LrDevelopController.setActiveColorGradingView]      = {module = 'develop', photoSelected = false },
  [LrDevelopController.setMultipleAdjustmentThreshold] = {module = 'develop', photoSelected = false },
  [LrDevelopController.setProcessVersion]              = {module = 'develop', photoSelected = true },
  [LrDevelopController.setTrackingDelay]               = {module = 'develop', photoSelected = false },
  [LrDevelopController.setValue]                       = {module = 'develop', photoSelected = true },
  [LrDevelopController.showClipping]                   = {module = 'develop', photoSelected = false},
  [LrDevelopController.startTracking]                  = {module = 'develop', photoSelected = false },
  [LrDevelopController.stopTracking]                   = {module = 'develop', photoSelected = false },
  [LrDevelopController.subtractFromCurrentMask]        = {module = 'develop', photoSelected = true },
}

local _needsModule = {
  __index = function (t,k)
    t[k] = {module = nil, photoSelected = false}
    return t[k]
  end
}
setmetatable ( needsModule, _needsModule)

--public

--------------------------------------------------------------------------------
-- Returns function passed to it, with appropriate switch to Lightroom module if
-- needed.
-- This should wrap a module-specific Lightroom SDK function call unless you
-- already know that Lightroom is set to the correct module. Stays in module that was
-- opened after function ends.
-- @tparam function F The function to use.
-- @param...Any arguments to the function.
-- @treturn function Function closure.
--------------------------------------------------------------------------------
local function wrapFOM(F,...)
  local openModule = needsModule[F]['module']
  if openModule == nil then
    return function()
      return F(unpack(arg))  --proper tail call
    end
  end
  return function()
    if needsModule[F]['photoSelected'] and LrApplication.activeCatalog():getTargetPhoto() == nil then return end
    if LrApplicationView.getCurrentModuleName() ~= openModule then
      LrApplicationView.switchToModule(openModule)
      LrTasks.yield() -- need this to allow module change before F is called
    end
    return F(unpack(arg)) --proper tail call
  end
end

--------------------------------------------------------------------------------
-- Executes function passed to it, with appropriate switch to Lightroom module if
-- needed.
-- This should wrap a module-specific Lightroom SDK function call unless you
-- already know that Lightroom is set to the correct module. Stays in module that was
-- opened after function ends.
-- @tparam function F The function to use.
-- @param...Any arguments to the function.
-- @return Results of passed function.
--------------------------------------------------------------------------------
local function execFOM(F,...)
  local openModule = needsModule[F]['module']
  if openModule == nil then
    return F(...) --proper tail call
  end
  if needsModule[F]['photoSelected'] and LrApplication.activeCatalog():getTargetPhoto() == nil then return end
  if LrApplicationView.getCurrentModuleName() ~= openModule then
    LrApplicationView.switchToModule(openModule)
    LrTasks.yield() -- need this to allow module change before F is called
  end
  return F(...) --proper tail call
end

local wfep_action = {
  QuickDevWBAuto                  = function(T) T:quickDevelopSetWhiteBalance("Auto") end,
  QuickDevWBCloudy                = function(T) T:quickDevelopSetWhiteBalance("Cloudy") end,
  QuickDevWBDaylight              = function(T) T:quickDevelopSetWhiteBalance("Daylight") end,
  QuickDevWBFlash                 = function(T) T:quickDevelopSetWhiteBalance("Flash") end,
  QuickDevWBFluorescent           = function(T) T:quickDevelopSetWhiteBalance("Fluorescent") end,
  QuickDevWBShade                 = function(T) T:quickDevelopSetWhiteBalance("Shade") end,
  QuickDevWBTungsten              = function(T) T:quickDevelopSetWhiteBalance("Tungsten") end,
  SetTreatmentBW                  = function(T) T:quickDevelopSetTreatment("grayscale") end,
  SetTreatmentColor               = function(T) T:quickDevelopSetTreatment("color") end,
  addOrRemoveFromTargetCollection = function(T) T:addOrRemoveFromTargetCollection() end,
  openExportDialog                = function(T) T:openExportDialog() end,
  openExportWithPreviousDialog    = function(T) T:openExportWithPreviousDialog() end,
  rotateLeft                      = function(T) T:rotateLeft() end,
  rotateRight                     = function(T) T:rotateRight() end,
}
-- equivalent to "LrApplication.activeCatalog():getTargetPhoto():rotateLeft()", e.g., with target checking
local function wrapForEachPhoto(F) --note lightroom applies this to all selected photos. no need to get all selected
  local SelectedAction = wfep_action[F]
  return function()
    local LrCat = LrApplication.activeCatalog()
    local TargetPhoto  = LrCat:getTargetPhoto()
    if TargetPhoto then
      SelectedAction(TargetPhoto)
    end
  end
end

local function QuickCropAspect(aspect)
  local TargetPhoto = LrApplication.activeCatalog():getTargetPhoto()
  if TargetPhoto then
    TargetPhoto:quickDevelopCropAspect(aspect)
  end
end

local sb_precisionList = {
  Blacks=0,
  BlueHue=0,
  BlueSaturation=0,
  Brightness=0,
  Clarity=0,
  ColorGradeBlending=0,
  ColorGradeGlobalHue=0,
  ColorGradeGlobalLum=0,
  ColorGradeGlobalSat=0,
  ColorGradeHighlightLum=0,
  ColorGradeMidtoneHue=0,
  ColorGradeMidtoneLum=0,
  ColorGradeMidtoneSat=0,
  ColorGradeShadowLum=0,
  ColorNoiseReduction=0,
  ColorNoiseReductionDetail=0,
  ColorNoiseReductionSmoothness=0,
  Contrast=0,
  CropAngle=3,
  CropBottom=3,
  CropLeft=3,
  CropRight=3,
  CropTop=3,
  DefringeGreenAmount=0,
  DefringeGreenHueHi=0,
  DefringeGreenHueLo=0,
  DefringePurpleAmount=0,
  DefringePurpleHueHi=0,
  DefringePurpleHueLo=0,
  Dehaze=0,
  Exposure=2,
  GrainAmount=0,
  GrainFrequency=0,
  GrainSize=0,
  GreenHue=0,
  GreenSaturation=0,
  Highlights=0,
  HueAdjustmentAqua=0,
  HueAdjustmentBlue=0,
  HueAdjustmentGreen=0,
  HueAdjustmentMagenta=0,
  HueAdjustmentOrange=0,
  HueAdjustmentPurple=0,
  HueAdjustmentRed=0,
  HueAdjustmentYellow=0,
  LensManualDistortionAmount=0,
  LensProfileChromaticAberrationScale=0,
  LensProfileDistortionScale=0,
  LensProfileVignettingScale=0,
  LuminanceAdjustmentAqua=0,
  LuminanceAdjustmentBlue=0,
  LuminanceAdjustmentGreen=0,
  LuminanceAdjustmentMagenta=0,
  LuminanceAdjustmentOrange=0,
  LuminanceAdjustmentPurple=0,
  LuminanceAdjustmentRed=0,
  LuminanceAdjustmentYellow=0,
  LuminanceNoiseReductionContrast=0,
  LuminanceNoiseReductionDetail=0,
  LuminanceSmoothing=0,
  ParametricDarks=0,
  ParametricHighlightSplit=0,
  ParametricHighlights=0,
  ParametricLights=0,
  ParametricMidtoneSplit=0,
  ParametricShadowSplit=0,
  ParametricShadows=0,
  PerspectiveAspect=0,
  PerspectiveHorizontal=0,
  PerspectiveRotate=1,
  PerspectiveScale=0,
  PerspectiveVertical=0,
  PerspectiveX=1,
  PerspectiveY=1,
  PostCropVignetteAmount=0,
  PostCropVignetteFeather=0,
  PostCropVignetteHighlightContrast=0,
  PostCropVignetteMidpoint=0,
  PostCropVignetteRoundness=0,
  RedHue=0,
  RedSaturation=0,
  Saturation=0,
  SaturationAdjustmentAqua=0,
  SaturationAdjustmentBlue=0,
  SaturationAdjustmentGreen=0,
  SaturationAdjustmentMagenta=0,
  SaturationAdjustmentOrange=0,
  SaturationAdjustmentPurple=0,
  SaturationAdjustmentRed=0,
  SaturationAdjustmentYellow=0,
  ShadowTint=0,
  Shadows=0,
  SharpenDetail=0,
  SharpenEdgeMasking=0,
  SharpenRadius=1,
  SplitToningBalance=0,
  SplitToningHighlightHue=0,
  SplitToningHighlightSaturation=0,
  SplitToningShadowHue=0,
  SplitToningShadowSaturation=0,
  Temperature=0,
  Texture=0,
  Tint=0,
  Vibrance=0,
  VignetteAmount=0,
  VignetteMidpoint=0,
  Whites=0,
  local_Blacks2012=0,
  local_Clarity=0,
  local_Contrast=0,
  local_Defringe=0,
  local_Dehaze=0,
  local_Exposure=2,
  local_Highlights=0,
  local_LuminanceNoise=0,
  local_Moire=0,
  local_Saturation=0,
  local_Shadows=0,
  local_Sharpness=0,
  local_Temperature=0,
  local_Tint=0,
  local_Whites2012=0,
  straightenAngle=3,
}
local function showBezel(param, value1, value2, prefixtxt)
  local precision = sb_precisionList[param] or 4
  -- uses processVersion to index bezelname
  local processVersion = tonumber(LrDevelopController.getProcessVersion():match('%-?%d+'))
  -- ternary operator idiom. Note: not quite ternary operator. If [processVersion] doesn't match an entry, will use param instead.
  -- if CmdTrans[param] exists, will try first [processVersion] then, if that doesn't exist, [LatestPVSupported], then fallback to param
  -- this is in case someone doesn't update MIDI2LR but Adobe goes to a higher process version not supported by MIDI2LR CmdTrans table
  local bezelname = Database.CmdTrans[param] and (Database.CmdTrans[param][processVersion] or Database.CmdTrans[param][Database.LatestPVSupported]) or param
  if prefixtxt then bezelname = prefixtxt..' '..bezelname end
  if value2 then
    LrDialogs.showBezel(bezelname..'  '..LrStringUtils.numberToStringWithSeparators(value1,precision)..'  ('..LOC("$$$/MIDI2LR/General/Pickup=picked up at")..' '..LrStringUtils.numberToStringWithSeparators(value2,precision)..')' )
  else
    LrDialogs.showBezel(bezelname..'  '..LrStringUtils.numberToStringWithSeparators(value1,precision))
  end
end

local nofilter = {
  columnBrowserActive=false,
  filtersActive=false,
  sesarchStringActive=false,
  label1=false,
  label2=false,
  label3=false,
  label4=false,
  label5=false,
  customLabel=false,
  noLabel=false,
  minRating=0,
  ratingOp=">=",
--pick="<nil>",
--edit="<nil>",
--whichCopies="<nil>",
  searchOp="all",
  searchString="",
  searchTarget="all",
  searchStringActive=false,
  gpsLocation=false,
  labelOp="any",
}
local function RemoveFilters()
  LrApplication.activeCatalog():setViewFilter(nofilter)
  if ProgramPreferences.ClientShowBezelOnChange then
    LrDialogs.showBezel(Database.CmdTrans.FilterNone[1]) --PV doesn't matter
  end
end

local function fApplyFilter(filternumber)
  return function()
    local filterUuid = ProgramPreferences.Filters[filternumber]
    if filterUuid == nil then return end
    local applied = LrApplication.activeCatalog():setViewFilter(filterUuid)
    if applied == false then
      RemoveFilters()
    else
      if ProgramPreferences.ClientShowBezelOnChange then
        local _,str = LrApplication.activeCatalog():getCurrentViewFilter()
        if str then LrDialogs.showBezel(str) end -- str nil if not defined
      end
    end
  end
end

local function fChangePanel(panelname)
  return function()
    execFOM(LrDevelopController.revealPanel,panelname)
    Profiles.changeProfile(panelname)
  end
end

local function fChangeModule(modulename)
  return function()
    LrApplicationView.switchToModule(modulename)
    Profiles.changeProfile(modulename)
  end
end

local function fToggle01(param)
  return function()
    if execFOM(LrDevelopController.getValue, param) == 0 then
      LrDevelopController.setValue(param,1)
    else
      LrDevelopController.setValue(param,0)
    end
  end
end

local function fToggle01Async(param)
  return function()
    LrTasks.startAsyncTask ( function ()
        --[[-----------debug section, enable by adding - to beginning this line
    LrMobdebug.on()
    --]]-----------end debug section
        if execFOM(LrDevelopController.getValue, param) == 0 then
          LrDevelopController.setValue(param,1)
        else
          LrDevelopController.setValue(param,0)
        end
      end )
  end
end

local function fToggle1ModN(param, N)
  return function()
    local v = execFOM(LrDevelopController.getValue, param)
    v = (v % N) + 1
    LrDevelopController.setValue(param,v)
  end
end

local function fToggleTFasync(param)
  return function()
    LrTasks.startAsyncTask ( function ()
        --[[-----------debug section, enable by adding - to beginning this line
    LrMobdebug.on()
    --]]-----------end debug section
        if LrApplication.activeCatalog():getTargetPhoto() == nil then return end
        LrApplication.activeCatalog():withWriteAccessDo(
          'MIDI2LR: Apply settings',
          function()
            local params = LrApplication.activeCatalog():getTargetPhoto():getDevelopSettings()
            params[param] = not params[param]
            LrApplication.activeCatalog():getTargetPhoto():applyDevelopSettings(params)
          end,
          { timeout = 4,
            callback = function()
              LrDialogs.showError(LOC("$$$/AgCustomMetadataRegistry/UpdateCatalog/Error=The catalog could not be updated with additional module metadata.")..' ApplySettings')
            end,
            asynchronous = true
          }
        )
      end
    )
  end
end

local function fToggleTool(param)
  return function()
    if LrApplicationView.getCurrentModuleName() ~= 'develop' then
      LrApplicationView.switchToModule('develop')
      LrTasks.yield() -- need this to allow module change before next action
    end
    if LrDevelopController.getSelectedTool() == param then -- toggle between the tool/loupe
      LrDevelopController.selectTool('loupe')
      Profiles.changeProfile('loupe', true)
    else
      LrDevelopController.selectTool(param)
      Profiles.changeProfile(param, true)
    end
  end
end

local ftt1_functionList = {
  dust = LrDevelopController.goToHealing,
  masking = LrDevelopController.goToMasking,
}

local function fToggleTool1(param) --for new version toggle tool
  return function()
    if LrApplicationView.getCurrentModuleName() == 'develop' and
    LrDevelopController.getSelectedTool() == param then
      LrDevelopController.selectTool('loupe')
    else
      ftt1_functionList[param]()
    end
  end
end


local function ApplySettings(settings)
  if LrApplication.activeCatalog():getTargetPhoto() == nil then return end
  LrTasks.startAsyncTask ( function ()
          --[[-----------debug section, enable by adding - to beginning this line
    LrMobdebug.on()
    --]]-----------end debug section
      LrApplication.activeCatalog():withWriteAccessDo(
        'MIDI2LR: Apply settings',
        function() LrApplication.activeCatalog():getTargetPhoto():applyDevelopSettings(settings) end,
        { timeout = 4,
          callback = function()
            LrDialogs.showError(LOC("$$$/AgCustomMetadataRegistry/UpdateCatalog/Error=The catalog could not be updated with additional module metadata.")..' ApplySettings')
          end,
          asynchronous = true
        }
      )
    end
  )
end

local function MIDIValueToLRValue(param, midi_value, finetune_start, manual)
  -- must be called when in develop module with photo selected
  -- map midi range to develop parameter range
  -- expects midi_value 0.0-1.0, doesn't protect against out-of-range
  local min,max = Limits.GetMinMax(param)
  local retval = midi_value * (max-min) + min
  if type(finetune_start) == 'number' then
    local lrstart = finetune_start * (max-min) + min
    local newrange = (math.abs(min) + math.abs(max)) / ProgramPreferences.FineMagnify
    local oldmin, oldmax = min, max
    min = lrstart - newrange / 2
    max = min + newrange
    local midi_center = finetune_start
    if manual then midi_center = 0.5 end
    retval = math.max(math.min(((midi_value - midi_center + 0.5) * (max-min) + min), oldmax), oldmin)
  end
  return retval
end

local function LRValueToMIDIValue(param, finetune_start, manual)
  -- needs to be called in Develop module with photo selected
  -- map develop parameter range to midi range
  local min,max = Limits.GetMinMax(param)
  local lrval = LrDevelopController.getValue(param)
  local retval = (lrval-min)/(max-min)
  if type(finetune_start) == 'number' then
    local lrstart = finetune_start * (max-min) + min
    local newrange = (math.abs(min) + math.abs(max)) / ProgramPreferences.FineMagnify
    min = lrstart - newrange / 2
    max = min + newrange
    local midi_center = finetune_start
    if manual then midi_center = 0.5 end
    retval = ((lrval - min) / (max - min)) - 0.5 + midi_center
  end
  return math.max(math.min(retval, 1), 0)
end

local function FullRefresh()
  -- !!!!!!!!!!!!!!!!!!! Similar code exists in Profile.doprofilechange and Client.AdjustmentChangeObserver and has to be changed accordingly !!!!!!!!!!!!!!!!!!!
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
        --local val_bottom = Profiles.CropSideRev(photoval[Profiles.CropSideOriented('CropBottom', photoval.orientation)], photoval.orientation)
        -- does not work: local param_top, param_left, param_bottom, param_right = table.unpack(select(2, Profiles.CropSideOriented('CropTop', photoval.orientation)))
        local _, params = Profiles.CropSideOriented('CropTop', photoval.orientation)
        local param_top, param_left, param_bottom, param_right = params[1], params[2], params[3], params[4]
        local val_bottom = Profiles.CropSideRev(photoval[param_bottom], param_bottom, photoval.orientation)
        MIDI2LR.SERVER:send(string.format('CropBottomRight %g\n', val_bottom))
        MIDI2LR.SERVER:send(string.format('CropBottomLeft %g\n', val_bottom))
        MIDI2LR.SERVER:send(string.format('CropAll %g\n', val_bottom))
        MIDI2LR.SERVER:send(string.format('CropBottom %g\n', val_bottom))
        --local val_top = photoval.CropTop
        --local val_top = Profiles.CropSideRev(photoval[Profiles.CropSideOriented('CropTop', photoval.orientation)], photoval.orientation)
        local val_top = Profiles.CropSideRev(photoval[param_top], param_top, photoval.orientation)
        MIDI2LR.SERVER:send(string.format('CropTopRight %g\n', val_top))
        MIDI2LR.SERVER:send(string.format('CropTopLeft %g\n', val_top))
        MIDI2LR.SERVER:send(string.format('CropTop %g\n', val_top))
        --local val_left = photoval.CropLeft
        --local val_right = photoval.CropRight
        --local val_left = Profiles.CropSideRev(photoval[Profiles.CropSideOriented('CropLeft', photoval.orientation)], photoval.orientation)
        --local val_right = Profiles.CropSideRev(photoval[Profiles.CropSideOriented('CropRight', photoval.orientation)], photoval.orientation)
        local val_left = Profiles.CropSideRev(photoval[param_left], param_left, photoval.orientation)
        local val_right = Profiles.CropSideRev(photoval[param_right], param_right, photoval.orientation)
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
          -- maybe give Crop items a different type than "parameter"
          if param:sub(1,4) ~= 'Crop' then
            local min,max = Limits.GetMinMax(param)
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
    Profiles.UpdateVariableMove(true)
  end )
end

local function fSimulateKeys(keys, developonly, tool)
  return function()
    if developonly then
      if LrApplicationView.getCurrentModuleName() == 'develop' and LrApplication.activeCatalog():getTargetPhoto() ~= nil then
        if tool == nil or tool[LrDevelopController.getSelectedTool()] then
          MIDI2LR.SERVER:send('SendKey '..keys..'\n')
        end
      end
    else
      MIDI2LR.SERVER:send('SendKey '..keys..'\n')
    end
  end
end

local function UpdatePointCurve(settings)
  return function()
    fChangePanel('tonePanel')
    ApplySettings(settings)
  end
end

local function PointCurveUpDown(blacks, moveup, color)
  return function()
    if LrApplicationView.getCurrentModuleName() ~= 'develop' or LrApplication.activeCatalog():getTargetPhoto() == nil then return end
    local maxamount = 5
    local  factor  = 0
    local setting = 'ToneCurvePV2012'
    if color then setting = setting..color end
    local points = LrDevelopController.getValue(setting)
    local newpoints = {}
    local xval = 0
    local testamount = 0
    -- Find the left and right most points
    local xmin, ymin, xmax, ymax, xmindid, xmaxdid = nil, nil, nil, nil, false, false
    for idx,val in ipairs(points) do
      if math.floor(idx/2) ~= idx/2 then -- odd number, i.e. x
        if val < (xmin or 256) then xmin = val; xmindid = true end
        if val > (xmax or 0) then xmax = val; xmaxdid = true end
      elseif xmindid then
        ymin = val
        xmindid = false
      elseif xmaxdid then
        ymax = val
        xmaxdid = false
      end
    end
    -- There are two scales (explanation for blacks):
    -- xscale: diminishes the point movement the further right the point is, where the left most point has full effect (1 => maxamount), the right most point has 0 (does not move at all)
    -- yscale: is the percentage how much maxamount is in relation to the y-value of the leftmost point; this is for awkward curves where the leftmost point is not the lowest one,
    -- in such cases the points lower than the leftmost have to be affected more to keep the shape of the curve intact, as those values are more 'extreme', they are affected more
    local yscale = 0
    local xscale = 0
    if blacks then
      if not moveup and ymin < maxamount then maxamount = ymin end
      yscale = maxamount / (255 - ymin)
    else
      if moveup and (255 - ymax) < maxamount then maxamount = (255 - ymax) end
      yscale = maxamount / ymax
    end
    xscale = 1 / (xmax - xmin)
    -- Now all points are moved. 'factor' is the diminishing effect of xscale depending on the actual x-value of the point
    for idx,val in ipairs(points) do
      if math.floor(idx/2) ~= idx/2 then -- odd number, i.e. x
        if blacks then
           factor  = 1 - (xscale * (val - xmin))^2.5
        else
           factor  = 1 - (xscale * (xmax - val))^2.5
        end
        xval = val
      else -- even number, i.e. y
        newpoints[#newpoints+1] = xval
        if not moveup then  factor  =  factor  * -1 end
        if blacks then
          testamount = val + yscale * (255 - val) * factor
        else
          testamount = val + yscale * val * factor
        end
        if testamount < 0 then testamount = 0 end
        if testamount > 255 then testamount = 255 end
        newpoints[#newpoints+1] = testamount
      end
    end
    fChangePanel('tonePanel')
    LrDevelopController.setValue(setting, newpoints)
  end
end

local cg_hsl_parms = {global={'ColorGradeGlobalHue','ColorGradeGlobalSat','ColorGradeGlobalLum'},
  highlight={'SplitToningHighlightHue','SplitToningHighlightSaturation','ColorGradeHighlightLum'},
  midtone={'ColorGradeMidtoneHue','ColorGradeMidtoneSat','ColorGradeMidtoneLum'},
  shadow={'SplitToningShadowHue','SplitToningShadowSaturation','ColorGradeShadowLum'}}

local cg_hsl = {0,0,0}

local function cg_hsl_copy()
  local currentView = LrDevelopController.getActiveColorGradingView()
  if currentView == '3-way' then
    return
  end
  cg_hsl = {LrDevelopController.getValue(cg_hsl_parms[currentView][1]),
    LrDevelopController.getValue(cg_hsl_parms[currentView][2]),
    LrDevelopController.getValue(cg_hsl_parms[currentView][3])}
end

local function cg_hsl_paste()
  local currentView = LrDevelopController.getActiveColorGradingView()
  if currentView == '3-way' then
    LrDevelopController.setValue(cg_hsl_parms.highlight[1],cg_hsl[1])
    LrDevelopController.setValue(cg_hsl_parms.highlight[2],cg_hsl[2])
    LrDevelopController.setValue(cg_hsl_parms.highlight[3],cg_hsl[3])
    LrDevelopController.setValue(cg_hsl_parms.midtone[1],cg_hsl[1])
    LrDevelopController.setValue(cg_hsl_parms.midtone[2],cg_hsl[2])
    LrDevelopController.setValue(cg_hsl_parms.midtone[3],cg_hsl[3])
    LrDevelopController.setValue(cg_hsl_parms.shadow[1],cg_hsl[1])
    LrDevelopController.setValue(cg_hsl_parms.shadow[2],cg_hsl[2])
    LrDevelopController.setValue(cg_hsl_parms.shadow[3],cg_hsl[3])
    FullRefresh()
    return
  end
  LrDevelopController.setValue(cg_hsl_parms[currentView][1],cg_hsl[1])
  LrDevelopController.setValue(cg_hsl_parms[currentView][2],cg_hsl[2])
  LrDevelopController.setValue(cg_hsl_parms[currentView][3],cg_hsl[3])
  FullRefresh()
end

local function cg_reset_3way()
  LrDevelopController.resetToDefault('SplitToningHighlightHue')
  LrDevelopController.resetToDefault('SplitToningHighlightSaturation')
  LrDevelopController.resetToDefault('ColorGradeHighlightLum')
  LrDevelopController.resetToDefault('ColorGradeMidtoneHue')
  LrDevelopController.resetToDefault('ColorGradeMidtoneSat')
  LrDevelopController.resetToDefault('ColorGradeMidtoneLum')
  LrDevelopController.resetToDefault('SplitToningShadowHue')
  LrDevelopController.resetToDefault('SplitToningShadowSaturation')
  LrDevelopController.resetToDefault('ColorGradeShadowLum')
  FullRefresh()
end

local function cg_reset_all()
  LrDevelopController.resetToDefault('ColorGradeGlobalHue')
  LrDevelopController.resetToDefault('ColorGradeGlobalSat')
  LrDevelopController.resetToDefault('ColorGradeGlobalLum')
  cg_reset_3way()
end

local function cg_reset_current()
  local currentView = LrDevelopController.getActiveColorGradingView()
  if currentView == '3-way' then
    cg_reset_3way()
    return
  end
  if currentView == 'global' then
    LrDevelopController.resetToDefault('ColorGradeGlobalHue')
    LrDevelopController.resetToDefault('ColorGradeGlobalSat')
    LrDevelopController.resetToDefault('ColorGradeGlobalLum')
    FullRefresh()
    return
  end
  if currentView == 'highlight' then
    LrDevelopController.resetToDefault('SplitToningHighlightHue')
    LrDevelopController.resetToDefault('SplitToningHighlightSaturation')
    LrDevelopController.resetToDefault('ColorGradeHighlightLum')
    FullRefresh()
    return
  end
  if currentView == 'midtone' then
    LrDevelopController.resetToDefault('ColorGradeMidtoneHue')
    LrDevelopController.resetToDefault('ColorGradeMidtoneSat')
    LrDevelopController.resetToDefault('ColorGradeMidtoneLum')
    FullRefresh()
    return
  end
  if currentView == 'shadow' then
    LrDevelopController.resetToDefault('SplitToningShadowHue')
    LrDevelopController.resetToDefault('SplitToningShadowSaturation')
    LrDevelopController.resetToDefault('ColorGradeShadowLum')
    FullRefresh()
    return
  end
end

local patrans = LOC('$$$/AgCameraRawNamedSettings/CameraRawSettingMapping/ProfileAmount=Profile amount')
local lastprofileadj = 0
local function ProfileAmount(value)
  if lastprofileadj + .1 > os.clock() then --throttle to 10x/second
    return
  end
  lastprofileadj = os.clock()
  local val = value -- make available to async task
  LrTasks.startAsyncTask ( function ()
          --[[-----------debug section, enable by adding - to beginning this line
    LrMobdebug.on()
    --]]-----------end debug section
      if LrApplication.activeCatalog():getTargetPhoto() == nil then return end
      LrApplication.activeCatalog():withWriteAccessDo(
        'MIDI2LR: Profile amount',
        function()
          local params = LrApplication.activeCatalog():getTargetPhoto():getDevelopSettings()
          if params and params.Look and params.Look.Amount then
            params.Look.Amount = val * 2
            LrApplication.activeCatalog():getTargetPhoto():applyDevelopSettings(params)
            if ProgramPreferences.ClientShowBezelOnChange then
              local bezelname = (Database.CmdTrans.ProfileAmount and Database.CmdTrans.ProfileAmount[Database.LatestPVSupported]) or patrans
              LrDialogs.showBezel(bezelname..'  '..LrStringUtils.numberToStringWithSeparators(val*200, 0))
            end
          end
        end,
        { timeout = 4,
          callback = function()
            LrDialogs.showError(LOC("$$$/AgCustomMetadataRegistry/UpdateCatalog/Error=The catalog could not be updated with additional module metadata.")..' '..patrans)
          end,
          asynchronous = true
        }
      )
    end
  )
end

local function ResetAllGrayMixer()
  LrDevelopController.resetToDefault('GrayMixerRed')
  LrDevelopController.resetToDefault('GrayMixerOrange')
  LrDevelopController.resetToDefault('GrayMixerYellow')
  LrDevelopController.resetToDefault('GrayMixerGreen')
  LrDevelopController.resetToDefault('GrayMixerAqua')
  LrDevelopController.resetToDefault('GrayMixerBlue')
  LrDevelopController.resetToDefault('GrayMixerPurple')
  LrDevelopController.resetToDefault('GrayMixerMagenta')
  if ProgramPreferences.ClientShowBezelOnChange then
    local bezelname = (Database.CmdTrans.ResetAllGrayMixer and Database.CmdTrans.ResetAllGrayMixer[Database.LatestPVSupported]) or "ResetAllGrayMixer"
    LrDialogs.showBezel(bezelname..'  '..LrStringUtils.numberToStringWithSeparators(0, 0))
  end
end

local function ResetAllHueAdjustment()
  LrDevelopController.resetToDefault('HueAdjustmentRed')
  LrDevelopController.resetToDefault('HueAdjustmentOrange')
  LrDevelopController.resetToDefault('HueAdjustmentYellow')
  LrDevelopController.resetToDefault('HueAdjustmentGreen')
  LrDevelopController.resetToDefault('HueAdjustmentAqua')
  LrDevelopController.resetToDefault('HueAdjustmentBlue')
  LrDevelopController.resetToDefault('HueAdjustmentPurple')
  LrDevelopController.resetToDefault('HueAdjustmentMagenta')
  if ProgramPreferences.ClientShowBezelOnChange then
    local bezelname = (Database.CmdTrans.ResetAllHueAdjustment and Database.CmdTrans.ResetAllHueAdjustment[Database.LatestPVSupported]) or "ResetAllHueAdjustment"
    LrDialogs.showBezel(bezelname..'  '..LrStringUtils.numberToStringWithSeparators(0, 0))
  end
end

local function ResetAllLuminanceAdjustment()
  LrDevelopController.resetToDefault('LuminanceAdjustmentRed')
  LrDevelopController.resetToDefault('LuminanceAdjustmentOrange')
  LrDevelopController.resetToDefault('LuminanceAdjustmentYellow')
  LrDevelopController.resetToDefault('LuminanceAdjustmentGreen')
  LrDevelopController.resetToDefault('LuminanceAdjustmentAqua')
  LrDevelopController.resetToDefault('LuminanceAdjustmentBlue')
  LrDevelopController.resetToDefault('LuminanceAdjustmentPurple')
  LrDevelopController.resetToDefault('LuminanceAdjustmentMagenta')
  if ProgramPreferences.ClientShowBezelOnChange then
    local bezelname = (Database.CmdTrans.ResetAllLuminanceAdjustment and Database.CmdTrans.ResetAllLuminanceAdjustment[Database.LatestPVSupported]) or "ResetAllLuminanceAdjustment"
    LrDialogs.showBezel(bezelname..'  '..LrStringUtils.numberToStringWithSeparators(0, 0))
  end
end

local function ResetAllSaturationAdjustment()
  LrDevelopController.resetToDefault('SaturationAdjustmentRed')
  LrDevelopController.resetToDefault('SaturationAdjustmentOrange')
  LrDevelopController.resetToDefault('SaturationAdjustmentYellow')
  LrDevelopController.resetToDefault('SaturationAdjustmentGreen')
  LrDevelopController.resetToDefault('SaturationAdjustmentAqua')
  LrDevelopController.resetToDefault('SaturationAdjustmentBlue')
  LrDevelopController.resetToDefault('SaturationAdjustmentPurple')
  LrDevelopController.resetToDefault('SaturationAdjustmentMagenta')
  if ProgramPreferences.ClientShowBezelOnChange then
    local bezelname = (Database.CmdTrans.ResetAllSaturationAdjustment and Database.CmdTrans.ResetAllSaturationAdjustment[Database.LatestPVSupported]) or "ResetAllSaturationAdjustment"
    LrDialogs.showBezel(bezelname..'  '..LrStringUtils.numberToStringWithSeparators(0, 0))
  end
  MIDI2LR.SERVER:send(string.format('%s %g\n', "AllSaturationAdjustment", LRValueToMIDIValue("SaturationAdjustmentRed")))
end

local cropbezel = LOC('$$$/AgCameraRawNamedSettings/SaveNamedDialog/Crop=Crop')..' ' -- no need to recompute each time we crop
local pct = '%'
if LrLocalization.currentLanguage() == 'fr' then
  pct = ' %'
end

local function RatioCrop(param, value, UpdateParam)
  if LrApplication.activeCatalog():getTargetPhoto() == nil then return end
  if LrApplicationView.getCurrentModuleName() ~= 'develop' then
    LrApplicationView.switchToModule('develop')
  end
  LrDevelopController.selectTool('crop')
  local prior_c_bottom = LrDevelopController.getValue("CropBottom") --starts at 1
  local prior_c_top = LrDevelopController.getValue("CropTop") -- starts at 0
  local prior_c_left = LrDevelopController.getValue("CropLeft") -- starts at 0
  local prior_c_right = LrDevelopController.getValue("CropRight") -- starts at 1
  local ratio = (prior_c_right - prior_c_left) / (prior_c_bottom - prior_c_top)
  if param == "CropTopLeft" then
    local new_top = tonumber(value)
    local new_left = prior_c_right - ratio * (prior_c_bottom - new_top)
    if new_left < 0 then
      new_top = prior_c_bottom - prior_c_right / ratio
      new_left = 0
    end
    UpdateParam("CropTop",new_top,
      cropbezel..LrStringUtils.numberToStringWithSeparators((prior_c_right-new_left)*(prior_c_bottom-new_top)*100,0)..pct)
    UpdateParam("CropLeft",new_left,true)
  elseif param == "CropTopRight" then
    local new_top = tonumber(value)
    local new_right = prior_c_left + ratio * (prior_c_bottom - new_top)
    if new_right > 1 then
      new_top = prior_c_bottom - (1 - prior_c_left) / ratio
      new_right = 1
    end
    UpdateParam("CropTop",new_top,
      cropbezel..LrStringUtils.numberToStringWithSeparators((new_right-prior_c_left)*(prior_c_bottom-new_top)*100,0)..pct)
    UpdateParam("CropRight",new_right,true)
  elseif param == "CropBottomLeft" then
    local new_bottom = tonumber(value)
    local new_left = prior_c_right - ratio * (new_bottom - prior_c_top)
    if new_left < 0 then
      new_bottom = prior_c_right / ratio + prior_c_top
      new_left = 0
    end
    UpdateParam("CropBottom",new_bottom,
      cropbezel..LrStringUtils.numberToStringWithSeparators((prior_c_right-new_left)*(new_bottom-prior_c_top)*100,0)..pct)
    UpdateParam("CropLeft",new_left,true)
  elseif param == "CropBottomRight" then
    local new_bottom = tonumber(value)
    local new_right = prior_c_left + ratio * (new_bottom - prior_c_top)
    if new_right > 1 then
      new_bottom = (1 - prior_c_left) / ratio + prior_c_top
      new_right = 1
    end
    UpdateParam("CropBottom",new_bottom,
      cropbezel..LrStringUtils.numberToStringWithSeparators((new_right-prior_c_left)*(new_bottom-prior_c_top)*100,0)..pct)
    UpdateParam("CropRight",new_right,true)
  elseif param == "CropAll" then
    local new_bottom = tonumber(value)
    local new_right = prior_c_left + ratio * (new_bottom - prior_c_top)
    if new_right > 1 then
      new_right = 1
    end
    local new_top = math.max(prior_c_bottom - new_bottom + prior_c_top,0)
    local new_left = new_right - ratio * (new_bottom - new_top)
    if new_left < 0 then
      new_top = new_bottom - new_right / ratio
      new_left = 0
    end
    UpdateParam("CropBottom",new_bottom,
      cropbezel..LrStringUtils.numberToStringWithSeparators((new_right-new_left)*(new_bottom-new_top)*100,0)..pct)
    UpdateParam("CropRight",new_right,true)
    UpdateParam("CropTop",new_top,true)
    UpdateParam("CropLeft",new_left,true)
  elseif param == "CropMoveVertical" then
    local new_top = (1 - (prior_c_bottom - prior_c_top)) * tonumber(value)
    local new_bottom = new_top - prior_c_top + prior_c_bottom
    UpdateParam("CropBottom",new_bottom,true)
    UpdateParam("CropTop", new_top)
  elseif param == "CropMoveHorizontal" then
    local new_left = (1 - (prior_c_right - prior_c_left)) * tonumber(value)
    local new_right = new_left - prior_c_left + prior_c_right
    UpdateParam("CropLeft",new_left,true)
    UpdateParam("CropRight", new_right)
  end
end

local function quickDevAdjust(par,val,cmd) --note lightroom applies this to all selected photos. no need to get all selected
  return function()
    LrTasks.startAsyncTask(
      function()
            --[[-----------debug section, enable by adding - to beginning this line
    LrMobdebug.on()
    --]]-----------end debug section
        local TargetPhoto  = LrApplication.activeCatalog():getTargetPhoto()
        if TargetPhoto then
          TargetPhoto:quickDevelopAdjustImage(par,val)
          if ProgramPreferences.ClientShowBezelOnChange then
            LrDialogs.showBezel(Database.CmdTrans[cmd][1])
          end
        end
      end
    )
  end
end

local function quickDevAdjustWB(par,val,cmd) --note lightroom applies this to all selected photos. no need to get all selected
  return function()
    LrTasks.startAsyncTask(
      function()
            --[[-----------debug section, enable by adding - to beginning this line
    LrMobdebug.on()
    --]]-----------end debug section
        local TargetPhoto  = LrApplication.activeCatalog():getTargetPhoto()
        if TargetPhoto then
          TargetPhoto:quickDevelopAdjustWhiteBalance(par,val)
          if ProgramPreferences.ClientShowBezelOnChange then
            LrDialogs.showBezel(Database.CmdTrans[cmd][1])
          end
        end
      end
    )
  end
end

local function VirtualCopyFromMaster()
  -- currently only supports the (one) target photo, for all selected loop through getTargetPhotos() (see ToggleKeyword in Keywords.lua)
  LrTasks.startAsyncTask(
    function()
      local LrCat = LrApplication.activeCatalog()
      local TargetPhoto = LrCat:getTargetPhoto()
      if TargetPhoto then
        if TargetPhoto:getRawMetadata('isVirtualCopy') then
          LrCat:setSelectedPhotos(TargetPhoto:getRawMetadata("masterPhoto"),{})
        end
        LrCat:createVirtualCopies()
        LrDialogs.showBezel("Virtual Copy from Master")
      end
    end
  )
end

local function Prev()
  -- Native function selects first photo if none is selected
  local TargetPhoto = LrApplication.activeCatalog():getTargetPhoto()
  if TargetPhoto then
    LrSelection.previousPhoto()
  else
    LrSelection.nextPhoto()
  end
end

local function Next()
  -- Native function selects last photo if none is selected
  local TargetPhoto = LrApplication.activeCatalog():getTargetPhoto()
  if TargetPhoto then
    LrSelection.nextPhoto()
  else
    LrSelection.previousPhoto()
  end
end

local function Select1Left()
  -- Extends selection to 1 left
  local TargetPhoto = LrApplication.activeCatalog():getTargetPhoto()
  if TargetPhoto then
    LrSelection.extendSelection('left',1)
  else
    LrSelection.extendSelection('right',1)
  end
end

local function Select1Right()
  -- Extends selection to 1 right
  local TargetPhoto = LrApplication.activeCatalog():getTargetPhoto()
  if TargetPhoto then
    LrSelection.extendSelection('right',1)
  else
    LrSelection.extendSelection('left',1)
  end
end

local function setController(param, value)
  LrTasks.startAsyncTask( function()
    if type(value) == 'number' then
      MIDI2LR.SERVER:send(string.format('%s %g\n', param, value))
    end
  end )
end

--[[ obsolete: if dialog is shown no input is accepted therefore a second click cannot confirm the dialog
local function DeleteSelected()
  LrTasks.startAsyncTask(function()
    local SelPhotos = LrApplication.activeCatalog():getTargetPhotos()
    --photo:getContainedCollections()
    --photo:getContainedPublishedCollections()
    --"$$$/AgExport/PhotoWasDeleted=Das Foto wurde gelöscht."
    local numreal = 0
    local numvirtual = 0
    for _,TarPhoto in ipairs(SelPhotos) do
      if TarPhoto:getRawMetadata('isVirtualCopy') then
        numvirtual = numvirtual + 1
      else
        numreal = numreal + 1
      end
    end
    if numreal+numvirtual == 0 then
      LrDialogs.message(LOC("$$$/AgSlideshow/Toolbar/toolbarInfoText/noSelPhotos=No SelPhotos selected."))
      return
    end
    local txt = ''
    local permant = LOC("$$$/MIDI2LR/DeleteDialog/ConformDelete/recycle=and moved to the recycle bin")
    if ProgramPreferences.DeleteAnyhow then
      permant = LOC("$$$/MIDI2LR/DeleteDialog/ConformDelete/permanent=permanently")
    end
    if numreal == 1 then
      txt = LOC("$$$/MIDI2LR/DeleteDialog/ConformDelete/Single=^1 photo (and all its virtual copies) will be deleted ^2. It will be removed from your Lr Catalog and any synced Lr clients.", numreal, permant)
    elseif numreal > 1 then
      txt = LOC("$$$/MIDI2LR/DeleteDialog/ConformDelete/Plural=^1 photos (and all their virtual copies) will be deleted ^2. They will be removed from your Lr Catalog and any synced Lr clients.", numreal, permant)
    end
    if numreal > 0 then
      if numvirtual == 1 then
        txt = txt..LOC("$$$/AgLibrary/DeleteDialog/Explanation/VirtualCopiesToo/Single=^1One virtual copy will also be removed.", " ")
      elseif numvirtual > 1 then
        txt = txt..LOC("$$$/AgLibrary/DeleteDialog/Explanation/VirtualCopiesToo/Plural=^1^2 virtual copies will also be removed.", " ", numvirtual)
      end
    else
      if numvirtual == 1 then
        txt = txt..LOC("$$$/AgLibrary/DeleteDialog/VirtualCopies/RemoveSingle=Remove the selected virtual copy?")
      elseif numvirtual > 1 then
        txt = txt..LOC("$$$/AgLibrary/DeleteDialog/VirtualCopies/RemovePlural=Remove the ^1 selected virtual copies?", numvirtual)
      end
    end
    LrDialogs.confirm(txt)
  end )
end
--]]

return {
  ApplySettings = ApplySettings,
  FullRefresh = FullRefresh,
  LRValueToMIDIValue = LRValueToMIDIValue,
  MIDIValueToLRValue = MIDIValueToLRValue,
  ProfileAmount = ProfileAmount,
  QuickCropAspect = QuickCropAspect,
  RatioCrop = RatioCrop,
  RemoveFilters = RemoveFilters,
  ResetAllGrayMixer = ResetAllGrayMixer,
  ResetAllHueAdjustment = ResetAllHueAdjustment,
  ResetAllLuminanceAdjustment = ResetAllLuminanceAdjustment,
  ResetAllSaturationAdjustment = ResetAllSaturationAdjustment,
  UpdatePointCurve = UpdatePointCurve,
  cg_hsl_copy = cg_hsl_copy,
  cg_hsl_paste = cg_hsl_paste,
  cg_reset_3way = cg_reset_3way,
  cg_reset_all = cg_reset_all,
  cg_reset_current = cg_reset_current,
  execFOM = execFOM,
  fApplyFilter = fApplyFilter,
  fChangeModule = fChangeModule,
  fChangePanel = fChangePanel,
  fSimulateKeys = fSimulateKeys,
  fToggle01 = fToggle01,
  fToggle01Async = fToggle01Async,
  fToggle1ModN = fToggle1ModN,
  fToggleTFasync = fToggleTFasync,
  fToggleTool = fToggleTool,
  fToggleTool1 = fToggleTool1,
  quickDevAdjust = quickDevAdjust,
  quickDevAdjustWB = quickDevAdjustWB,
  showBezel = showBezel,
  wrapFOM = wrapFOM,
  wrapForEachPhoto = wrapForEachPhoto,
  VirtualCopyFromMaster = VirtualCopyFromMaster,
  Prev = Prev,
  Next = Next,
  Select1Right = Select1Right,
  Select1Left = Select1Left,
  fConfirmDialog = fConfirmDialog,
  DeleteSelected = DeleteSelected,
  PointCurveUpDown = PointCurveUpDown,
  setController = setController,
}
