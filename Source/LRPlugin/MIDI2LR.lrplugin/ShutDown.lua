--[[----------------------------------------------------------------------------

ShutDown.lua
Closes the app
 
This file is part of MIDI2LR. Copyright 2015-2016 by Rory Jaffe.

MIDI2LR is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later version.

MIDI2LR is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
MIDI2LR.  If not, see <http://www.gnu.org/licenses/>. 
------------------------------------------------------------------------------]]

return {
  LrShutdownFunction = function(doneFunction, progressFunction) 
    local LrPathUtils         = import 'LrPathUtils'
    local LrShell             = import 'LrShell'	
    local LrTasks             = import 'LrTasks'

    if ProgramPreferences.StopServerOnExit then
      progressFunction (0, LOC("$$$/AgPluginManager/Status/HttpServer/StopServer=Stop Server"))
      LrTasks.startAsyncTask(function()
          MIDI2LR.RUNNING = false
        end
      )
      LrTasks.startAsyncTask(function()
          if(WIN_ENV) then
            LrShell.openFilesInApp({'--LRSHUTDOWN'}, LrPathUtils.child(_PLUGIN.path, 'MIDI2LR.exe'))
          else
            LrTasks.execute('kill `pgrep MIDI2LR`') -- extreme, but maybe it'll work until I can close it more gracefully
          end
        end
      )

      progressFunction (1, LOC("$$$/AgPluginManager/Status/HttpServer/StopServer=Stopping Server"))
    end
    doneFunction() --call whether or not we stop the server
  end
}