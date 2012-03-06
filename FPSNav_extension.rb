=begin
    FPS Navigator Plugin for Google SketchUp
     Copyright 2011
     Alan Chatham
     
    This file is part of FPS Navigator Plugin.

    The FPS Navigator Plugin is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    The FPS Navigator Plugin is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with the FPS Navigator Plugin.  If not, see <http://www.gnu.org/licenses/>.

=end

# Loader for the FPSNav extension
     require 'sketchup.rb'
     require 'extensions.rb'

     fpsNav = SketchupExtension.new "FPSNav", "FPSNav/FPSNav.rb"
     fpsNav.version = '0.4'
     fpsNav.copyright = "2012"
     fpsNav.creator = "Alan Chatham"
     fpsNav.description = "First-Person Shooter Style Navigation."
     fpsNav.description += "  When active, move with the arrow keys; alternately, hold 'Shift' and move with WASD, or use the numeric keypad."
     fpsNav.description += "  Movement is restricted to the X-Y Plane."
     fpsNav.description += "  Pressing Shift + Q will move you down in the Z direction, and Shift + E will move you up."
     fpsNav.description += "  Alternatively, 7 and 9 on the numeric keypad do the same"
     fpsNav.description += "  Left-click the mouse and hold to look around"
     fpsNav.description += "  Double-clicking also toggles mouselook on."
     fpsNav.description += "  Movement speed and mouse sensitivity can be found in the 'Plugins/FPSNav Options' menu."
     Sketchup.register_extension(fpsNav, true)