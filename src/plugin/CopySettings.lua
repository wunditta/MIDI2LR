--[[----------------------------------------------------------------------------

CopySettings.lua

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

local number_of_presets = 6
local CpyStgClipboard = {}

-- Standard setting set is first set after title; if process version >= 6.7 second set is used
-- The first parameter array is with LrPhoto:get/setDevelopSettings; the optional second with LrDevelopController:get/setValue
-- Note: The plugin-extras > Build command creates a file 'DevelopSettings.md' with all currently available settings, as the official documentation is not up-to-date
local CopyStructure = {
  { id = 1, title = LOC("$$$/AgDevelop/CameraRawPanel/LensCorrection/Profile=Profile"), group = LOC("$$$/AgCameraRawNamedSettings/SaveNamedDialog/TreatmentAndProfile=Treatment and Profile"), photo = {'CameraProfile'}, devctrl = {'ProfileAmount'} }, 
  { id = 2, title = LOC("$$$/AgLibrary/Filter/BrowserCriteria/Treatment/ColorAndBW=Treatment (Color, BW)"), photo = {'ConvertToGrayscale'} }, 
  { id = 3, title = LOC("$$$/AgDevelop/Settings/WhiteBalance=White Balance"), group = LOC("$$$/AgCameraRawNamedSettings/SaveNamedDialog/Basic=Basic"), photo = {'WhiteBalance'} }, 
  { id = 4, title = LOC("$$$/AgDevelop/Settings/Exposure=Exposure"), photo = {'Exposure', 'Exposure2012'} }, 
  { id = 5, title = LOC("$$$/AgDevelop/Settings/Temperature=Temperature"), photo = {'Temperature'} }, 
  { id = 6, title = LOC("$$$/AgDevelop/Settings/Tint=Tint"), photo = {'Tint'} }, 
  { id = 7, title = LOC("$$$/AgDevelop/Settings/Contrast=Contrast"), photo = {'Contrast', 'Contrast2012'} }, 
  { id = 8, title = LOC("$$$/AgDevelop/Settings/Highlights=Highlights"), photo = {'Highlights2012'} }, 
  { id = 9, title = LOC("$$$/AgDevelop/Settings/Whites=Whites"), photo = {'Whites2012'} }, 
  { id = 10, title = LOC("$$$/AgDevelop/Settings/Shadows=Shadows"), photo = {'Shadows', 'Shadows2012'} }, 
  { id = 11, title = LOC("$$$/AgDevelop/Settings/Blacks=Blacks"), photo = {'Blacks2012'} }, 
  { id = 12, title = LOC("$$$/AgDevelop/Settings/Texture=Texture"), photo = {'Texture'} }, 
  { id = 13, title = LOC("$$$/AgDevelop/Settings/Clarity=Clarity"), photo = {'Clarity', 'Clarity2012'} }, 
  { id = 14, title = LOC("$$$/AgDevelop/Settings/Dehaze=Dehaze"), photo = {'Dehaze'} }, 
  { id = 15, title = LOC("$$$/AgDevelop/Settings/Vibrance=Vibrance"), photo = {'Vibrance'} }, 
  { id = 16, title = LOC("$$$/AgDevelop/Settings/Saturation=Saturation"), photo = {'Saturation'} }, 
  { id = 17, title = LOC("$$$/AgDevelop/CameraRawPanel/ParametricEnabledTooltip=Parametric Curve"), group = LOC("$$$/AgDevelop/Localized/Panel/Curve=Curve"), photo = {'ParametricDarks', 'ParametricLights', 'ParametricShadows', 'ParametricHighlights', 'ParametricShadowSplit', 'ParametricMidtoneSplit', 'ParametricHighlightSplit'} }, 
  { id = 18, title = LOC("$$$/AgDevelop/CameraRawPanel/TargetName/ToneCurve=Tone Curve"), photo = {'ToneCurveName2012','ToneCurvePV2012', 'ToneCurvePV2012Red', 'ToneCurvePV2012Blue', 'ToneCurvePV2012Green', 'CurveRefineSaturation'} }, 
  { id = 19, title = LOC("$$$/AgCameraRawNamedSettings/SaveNamedDialog/ColorAdjustments=HSL/Color"), group = '', photo = {
    'HueAdjustmentRed', 'HueAdjustmentOrange', 'HueAdjustmentYellow', 'HueAdjustmentGreen', 'HueAdjustmentAqua', 'HueAdjustmentBlue', 'HueAdjustmentPurple', 'HueAdjustmentMagenta',
    'SaturationAdjustmentRed', 'SaturationAdjustmentOrange', 'SaturationAdjustmentYellow', 'SaturationAdjustmentGreen', 'SaturationAdjustmentAqua', 'SaturationAdjustmentBlue', 'SaturationAdjustmentPurple', 'SaturationAdjustmentMagenta',
    'LuminanceHueAdjustmentRed', 'LuminanceHueAdjustmentOrange', 'LuminanceHueAdjustmentYellow', 'LuminanceHueAdjustmentGreen', 'LuminanceHueAdjustmentAqua', 'LuminanceHueAdjustmentBlue', 'LuminanceHueAdjustmentPurple', 'LuminanceHueAdjustmentMagenta',
    --'GrayMixerRed', 'GrayMixerOrange', 'GrayMixerYellow', 'GrayMixerGreen', 'GrayMixerAqua', 'GrayMixerBlue', 'GrayMixerPurple', 'GrayMixerMagenta',
    }
  }, 
  { id = 20, title = LOC("$$$/AgDevelop/Panel/ColorGrading=Color Grading"), group = '', photo = {
    'SplitToningShadowHue', 'SplitToningShadowSaturation', 'ColorGradeShadowLum',
    'SplitToningHighlightHue', 'SplitToningHighlightSaturation', 'ColorGradeHighlightLum', 
    'ColorGradeMidtoneHue', 'ColorGradeMidtoneSat', 'ColorGradeMidtoneLum', 
    'ColorGradeGlobalHue', 'ColorGradeGlobalSat', 'ColorGradeGlobalLum', 
    'SplitToningBalance', 'ColorGradeBlending', 
    }
  }, 
  { id = 21, title = LOC("$$$/AgDevelop/CameraRawPanel/Detail/Sharpening=Sharpening"), group = LOC("$$$/AgDevelop/Panel/Detail=Detail"), photo = {'Sharpness', 'SharpenRadius', 'SharpenDetail', 'SharpenEdgeMasking'} }, 
  { id = 22, title = LOC("$$$/AgCameraRawNamedSettings/CameraRawSettingMapping/LuminanceSmoothing=Luminance Noise Reduction"), photo = {'LuminanceSmoothing', 'LuminanceNoiseReductionDetail', 'LuminanceNoiseReductionContrast'} }, 
  { id = 23, title = LOC("$$$/AgCameraRawNamedSettings/CameraRawSettingMapping/ColorNoiseReduction=Color Noise Reduction"), photo = {'ColorNoiseReduction', 'ColorNoiseReductionDetail', 'ColorNoiseReductionSmoothness'} }, 
  { id = 24, title = LOC("$$$/AgDevelop/CameraRawPanel/LensCorrection/LensProfile=Lens Profile Correction"), group = LOC("$$$/AgDevelop/Panel/LensCorrections=Lens Corrections"), photo = {'LensProfileEnable', 'LensProfileSetup', 'LensProfileDistortionScale', 'LensProfileVignettingScale'} }, -- Not all settings are documented by Adobe
  { id = 25, title = LOC("$$$/AgCameraRawNamedSettings/CameraRawSettingMapping/RemoveChromaticAberration=Remove Chromatic Aberration"), photo = {'AutoLateralCA', 'DefringePurpleAmount', 'DefringePurpleHueLo', 'DefringePurpleHueHi', 'DefringeGreenAmount', 'DefringeGreenHueLo', 'DefringeGreenHueHi'} }, 
  { id = 26, title = LOC("$$$/AgDevelop/CameraRawPanel/LensCorrection/Manual=Manual")..' '..LOC("$$$/AgDevelop/CameraRawPanel/LensCorrection/Distortion=Distortion"), photo = {'LensManualDistortionAmount'} }, 
  { id = 27, title = LOC("$$$/AgDevelop/CameraRawPanel/LensCorrection/Manual=Manual")..' '..LOC("$$$/AgDevelop/CameraRawPanel/LensCorrection/Vignetting=Vignetting"), photo = {'VignetteAmount', 'VignetteMidpoint'} }, 
  { id = 28, title = LOC("$$$/AgCameraRawNamedSettings/SaveNamedDialog/UprightMode=Upright Mode"), group = LOC("$$$/AgDevelop/CameraRawPanel/Transform=Transform"), photo = {'PerspectiveUpright'} }, 
  { id = 29, title = LOC("$$$/AgCameraRawNamedSettings/SaveNamedDialog/ManualTransforms=Manual Transforms"), photo = {'PerspectiveAspect', 'PerspectiveHorizontal', 'PerspectiveRotate', 'PerspectiveScale', 'PerspectiveUpright', 'PerspectiveVertical', 'PerspectiveX', 'PerspectiveY'} }, 
  { id = 30, title = LOC("$$$/AgDevelop/Settings/PostCropVignette=Post-Crop Vignetting"), group = LOC("$$$/AgDevelop/Panel/Effects=Effects"), photo = {'PostCropVignetteAmount', 'PostCropVignetteFeather', 'PostCropVignetteHighlightContrast', 'PostCropVignetteMidpoint', 'PostCropVignetteRoundness', 'PostCropVignetteStyle'} }, 
  { id = 31, title = LOC("$$$/AgDevelop/Settings/Grain=Grain"), photo = {'GrainAmount', 'GrainFrequency', 'GrainSize'} }, 
  { id = 32, title = LOC("$$$/AgCameraRawNamedSettings/CameraRawSettingMapping/CropRectangle=Crop Rectangle"), group = LOC("$$$/AgDevelop/Crop=Crop"), photo = {'CropLeft', 'CropRight', 'CropTop', 'CropBottom'} }, 
  { id = 33, title = LOC("$$$/AgCameraRawNamedSettings/CameraRawSettingMapping/CropAngle=Crop Angle"), photo = {'CropAngle'} }, 
  { id = 34, title = LOC("$$$/AgCameraRawNamedSettings/CameraRawSettingMapping/CropAspect=Crop Aspect Ratio"), photo = {'CropConstrainToWarp'} }, 
  { id = 35, title = LOC("$$$/AgDevelop/Menu/Panels/Calibration=Calibration"), group = '', photo = {'ShadowTint', 'RedHue', 'RedSaturation', 'GreenHue', 'GreenSaturation', 'BlueHue', 'BlueSaturation'} }, 
  { id = 36, title = LOC("$$$/AgDevelop/Menu/ProcessVersion=Process Version"), group = '', photo = {'ProcessVersion'} }, 
}

local function StartDialog(obstable,f)
  local dlgrow = {}
  local dlgcol = { f:static_text{title='', width=LrView.share('copystggrp')}, f:static_text{title='', width=LrView.share('copystgtxt')} }
  for i = 1,number_of_presets do
    dlgcol[#dlgcol+1] = f:static_text{ title=LOC("$$$/AgDevelop/Setting/Preset=Preset")..' '..i, width = LrView.share('copystgcol'..i) }
    if type(ProgramPreferences.CopySettings[i]) ~= 'table' then ProgramPreferences.CopySettings[i] = {} end
    for _,stg in ipairs(CopyStructure) do
      obstable['copysetg'..i..'-'..stg.id] = ProgramPreferences.CopySettings[i][stg.id] == true
    end
  end
  dlgrow[1] = f:row(dlgcol)
  for _,stg in ipairs(CopyStructure) do
    dlgcol = {}
    for i = 1,number_of_presets do
      if i == 1 then
        if stg.group then
          dlgrow[#dlgrow+1] = f:row{ f:spacer{height=2} }
          dlgrow[#dlgrow+1] = f:row{ f:separator{fill_horizontal = 1} }
          dlgrow[#dlgrow+1] = f:row{ f:spacer{height=4} }
        end
        dlgcol[1] = f:static_text{ title = (stg.group or ''), width = LrView.share('copystggrp') }
        dlgcol[2] = f:static_text{ title = stg.title, width = LrView.share('copystgtxt') }
        dlgcol[3] = f:checkbox{ value = LrView.bind('copysetg'..i..'-'..stg.id), width = LrView.share('copystgcol'..i) }
      else
        dlgcol[#dlgcol+1] = f:checkbox { value = LrView.bind('copysetg'..i..'-'..stg.id), width = LrView.share('copystgcol'..i) }
      end
    end
    dlgrow[#dlgrow+1] = f:row(dlgcol)
    dlgrow[#dlgrow]['bind_to_object'] = obstable
  end
  dlgcol = {}
  dlgcol[1] = f:static_text{ title = '', width = LrView.share('copystggrp') }
  dlgcol[2] = f:static_text{ title = '', width = LrView.share('copystgtxt') }
  for i = 1,number_of_presets do
    dlgcol[#dlgcol+1] = f:push_button { title = LOC("$$$/Develop/Localized/Reset=Reset"),
    	action = function()
			  for _,stg in ipairs(CopyStructure) do
    			obstable['copysetg'..i..'-'..stg.id] = false
    		end
    		obstable['copysetg'..i..'-'..36] = true
    	end,
    	width = LrView.share('copystgcol'..i) }
  end
  dlgrow[#dlgrow+1] = f:row(dlgcol)
  return f:column(dlgrow)
end

local function EndDialog(obstable, status)
  if status == 'ok' then
    ProgramPreferences.CopySettings = {} -- empty out prior settings
    for i=1, number_of_presets do
      ProgramPreferences.CopySettings[i] = {}
      for _,stg in ipairs(CopyStructure) do
        if obstable['copysetg'..i..'-'..stg.id] then ProgramPreferences.CopySettings[i][stg.id] = true end
      end
    end
  end
end

local function CopySettingsCopy(preset)
  return function()
    LrTasks.startAsyncTask ( function ()
      local photo = LrApplication.activeCatalog():getTargetPhoto()
      if preset == nil or photo == nil then return end
      CpyStgClipboard[preset] = photo:getDevelopSettings()
    end )
  end
end

local function CopySettingsPaste(preset)
  return function()
    LrTasks.startAsyncTask ( function ()
      local photos = LrApplication.activeCatalog():getTargetPhotos()
      if preset == nil or type(photos) ~= 'table' then return end
      if CpyStgClipboard[preset] == nil then
        LrDialogs.message(LOC("$$$/MIDI2LR/CopyPresets/CopyPresets/NoCopy=You must copy settings from a photo first before you can apply them to other photos."), '', 'warning')
        return
      end
      local applysettings = {}
      for _,item in ipairs(CopyStructure) do
        if ProgramPreferences.CopySettings[preset][item.id] then
          for _,stg in ipairs(item.photo) do
            applysettings[stg] = CpyStgClipboard[preset][stg]
          end
        end
      end
      --if #applysettings == 0 then return end
      LrApplication.activeCatalog():withWriteAccessDo(
        LOC("$$$/MIDI2LR/CopyPresets/CopyPresets/History=MIDI2Lr: Paste Develop Settings Preset")..' '..preset,
        function()
          local warned = false
          for _,photo in ipairs(photos) do
            if photo:getRawMetadata('isVideo') then
              if not warned then
                LrDialogs.message(LOC('$$$/Library/VirsualSearchGrid/VideoSearch/Title=Video is not supported'..'.'), '', 'warning')
                warned = true
              end
              break
            end
            photo:applyDevelopSettings(applysettings, LOC("$$$/MIDI2LR/CopyPresets/CopyPresets/History=MIDI2Lr: Paste Develop Settings Preset")..' '..preset)
          end
        end,
        { timeout = 4,
          callback = function()
            LrDialogs.showError(LOC("$$$/AgCustomMetadataRegistry/UpdateCatalog/Error=The catalog could not be updated with additional module metadata.")..' ApplySettings')
          end,
          asynchronous = true
        }
      )
    end )
  end
end

return {
  StartDialog = StartDialog,
  EndDialog = EndDialog,
  CopySettingsCopy = CopySettingsCopy,
  CopySettingsPaste = CopySettingsPaste,
  number_of_presets = number_of_presets,
}
