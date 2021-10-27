=begin
	FPS Navigator Plugin for Google SketchUp
	Copyright 2011
	Alan Chatham (alan.chatham@gmail.com)

	This file is part of FPS Navigator Plugin.

	The FPS Navigator Plugin is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	The FPS Navigator Plugin is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with the FPS Navigator Plugin. If not, see <http://www.gnu.org/licenses/>.

=end


require 'sketchup.rb'



class Chatham_FPSNavigator
	# Some constants for timing the animations
	@@Chatham_FPSNav_framesPerSecond = 45
	@@Chatham_FPSNav_pauseLength = 1.0 / @@Chatham_FPSNav_framesPerSecond
	# For these, lower numbers are more sensitive
	@@Chatham_FPSNav_xSensitivity = (Sketchup.read_default "Chatham_FPSNav", "Chatham_FPSNav_xSensitivity", 400).to_i
	@@Chatham_FPSNav_ySensitivity = (Sketchup.read_default "Chatham_FPSNav", "Chatham_FPSNav_ySensitivity", 600).to_i
	@@Chatham_FPSNav_moveSpeed = (Sketchup.read_default "Chatham_FPSNav", "Chatham_FPSNav_moveSpeed", 2).to_f
	@FPS_accel = 1
	@@Chatham_FPSNav_accelerationUnit = 0.3
	@@Chatham_FPSNav_maxSpeed = 20
	@@SensitivityMax = 800
	@@SensitivityMin = 200

	def initialize
	end

	# This is called when the tool gets activated
	def activate()
		Sketchup.vcb_label = "Eye level = "
		# This holds a point and a direction for our camera
		@FPSNav_cameraTransformation
		# Create a camera that has the same features as the
		# current scene's camera
		# First, get the current view
		@FPSNav_currentView = Sketchup.active_model.active_view
		# And the current camera
		sceneCamera = @FPSNav_currentView.camera

		# And set our variables to the current camera's variables
		@FPSNav_eye = sceneCamera.eye
		@FPSNav_target = sceneCamera.target
		#@FPSNav_target.z = @FPSNav_eye.z
		@FPSNav_up = 0,0,1# sceneCamera.up
		# And create a new camera!
		#@FPSNav_myCamera = Sketchup::Camera.new(@FPSNav_eye, @FPSNav_target, @FPSNav_up)
		# And show the eye height
		Sketchup.vcb_value = @FPSNav_eye.z;

		reset
		#This timer controls how often the movement should update
		@FPSNav_updateTimer = UI.start_timer(@@Chatham_FPSNav_pauseLength, true) {update}
	end

	def reset
		# Variables for holding key press information
		@FPSNav_movingFlag = 0
		@FPSNav_moveKeyFlags = 0; # U, DOWN, FORWARD, BACKWARD, LEFT, RIGHT are the last 6 bits
		# These hold info about the mouse. The first two get updated when the mouse moves,
		# the second 2 when mouse look happens
		@FPSNav_mouseX = 0
		@FPSNav_mouseY = 0
		@FPSNav_prevMouseX = 0
		@FPSNav_prevMouseY = 0
		@FPSNav_mouseClickedFlag = 0
		if @FPSNav_updateTimer != nil
			UI.stop_timer(@FPSNav_updateTimer)
			@FPSNav_updateTimer = nil
		end
	end

	#Cleanup
	def deactivate(view)
		reset
	end

	def onCancel(reason, view)
		reset
		Sketchup.active_model.tools.pop_tool() if reason == 0
	end

	# onKeyDown is called when the user presses a key on the keyboard.
	# We are checking it here to see if the user pressed the shift key
	# so that we can do inference locking
	def onKeyDown(key, repeat, flags, view)
		# mac: only arrow key #A, Left, or Numpad 4
		if ((key == 65 && repeat == 1) || (key == 63234 && repeat == 1)	|| (key == VK_LEFT && repeat == 1) || (key == 100 && repeat == 1) )
			@FPSNav_moveKeyFlags |= 0b0010
		end
		# mac: only arrow key #D, Right, or Numpad 6
		if ((key == 68 && repeat == 1) || (key == 63235 && repeat == 1)	|| (key == VK_RIGHT && repeat == 1) || (key == 102 && repeat == 1) )
			@FPSNav_moveKeyFlags |= 0b0001
		end
		# mac: only arrow key #W, Up, or Numpad 8
		if ((key == 87 && repeat == 1) || (key == 63232 && repeat == 1)	|| (key == VK_UP && repeat == 1) || (key == 104 && repeat == 1) )
			@FPSNav_moveKeyFlags |= 0b1000
		end
		# mac: only arrow key #S, Down, or Numpad 5
		if ((key == 83 && repeat == 1) || (key == 63233 && repeat == 1)	|| (key == VK_DOWN && repeat == 1) || (key == 101 && repeat == 1) )
			@FPSNav_moveKeyFlags |= 0b0100
		end
		# mac > or command key #E or Numpad 9
		if ((key == 69 && repeat == 1) || (key == 46 && repeat == 1) || (key == VK_COMMAND && repeat == 1) )
			@FPSNav_moveKeyFlags |= 0b100000
		end
		# mac < or option key #X or Numpad 7
		if ((key == 88 && repeat == 1) || (key == 44 && repeat == 1) || (key == VK_ALT && repeat == 1) )
			@FPSNav_moveKeyFlags |= 0b010000
		end
		#Eventually...
		if (@FPSNav_movingFlag == 0 && @FPSNav_moveKeyFlags > 0)
			@FPSNav_movingFlag = 1;
		end

#puts "onKeyDown: key = " + key.to_s
#puts "  repeat = " + repeat.to_s
#puts "  accel = " + @FPS_accel.to_s
#puts "  flags = " + flags.to_s
#puts "  view = " + view.to_s
	end

	def onKeyUp(key, repeat, flags, view)
		# mac: only arrow key #A, Left, Numpad 4, or mac 'a'
		if ((key == 65) || (key == 63234) || (key == VK_LEFT) || (key == 100) || (key == 97))
			@FPSNav_moveKeyFlags &= ~0b0010
		end
		# mac: only arrow key #D, Right, Numpad 6, or mac 'd'
		if ((key == 68) || (key == 63235) || (key == VK_RIGHT) || (key == 102) || (key == 100) )
			@FPSNav_moveKeyFlags &= ~0b0001
		end
		# mac: only arrow key #W, Up, Numpad 8, or mac 'w'
		if ((key == 87) || (key == 63232) || (key == VK_UP) || (key == 104) || (key == 119) )
			@FPSNav_moveKeyFlags &= ~0b1000
		end
		# mac: only arrow key #S, Down, Numpad 5, or mac 's'
		if ((key == 83) || (key == 63233) || (key == VK_DOWN) || (key == 101) || (key == 115) )
			@FPSNav_moveKeyFlags &= ~0b0100
		end
		# mac > or command key #E or Numpad 9
		if((key == 69) || (key == 46) || (key == VK_COMMAND) )
			@FPSNav_moveKeyFlags &= ~0b100000
		end
		# mac < or option key #X or Numpad 7
		if((key == 88) || (key == 44) || (key == VK_ALT) )
			@FPSNav_moveKeyFlags &= ~0b010000
		end
		# If we were moving and let all the movement keys go, stop the moving routine
		if ((@FPSNav_movingFlag == 1 ) && (@FPSNav_moveKeyFlags == 0 ))
			@FPS_accel = 1
			@FPSNav_movingFlag = 0
		end
	end

	def moveCamera
		#First, get rid of the combinations that don't move (UP + DOWN, LEFT + RIGHT, all movement)
		if (@FPSNav_moveKeyFlags == 0b1100 || @FPSNav_moveKeyFlags == 0b0011 || @FPSNav_moveKeyFlags == 0b1111)
			return
		end
		#Now, set up the vector we want to move on
		movementVector = Geom::Vector3d.new(0,0,0)
		# First, Get the vector we between the camera and the view target
		# We'll use this to calculate perpedicular vectors should we need to later
		forwardVector = @FPSNav_target - @FPSNav_eye
		# Eliminate the z component
		#forwardVector.z = 0
		# If we're facing straight down, then make the movement vector the upward vector instead
		movementUp = @FPSNav_up
		if (forwardVector.length == 0)
			forwardVector = @FPSNav_currentView.camera.up
			movementUp = forwardVector
		end
		# Make the length equal 1
		forwardVector.normalize!

		# Now start adding the appropriate movement vectors together
		# Forward
		if ((@FPSNav_moveKeyFlags & 0b1000) != 0)
			movementVector += forwardVector
		end
		# Backward
		if ((@FPSNav_moveKeyFlags & 0b0100) != 0)
			movementVector -= forwardVector
		end
		# Left
		if ((@FPSNav_moveKeyFlags & 0b0010) != 0)
			# Math for rotating the forward vector 90 degrees left
			# x' = x cos 90 - y sin 90; y' = x sin 90 + y cos 90
			# x' = x * 0 - y * 1; y' = x * 1 + y * 0
			leftVector = Geom::Vector3d.new((-1 * forwardVector.y), forwardVector.x, 0)
			movementVector += leftVector
		end
		# Right
		if ((@FPSNav_moveKeyFlags & 0b0001) != 0)
			# Math for rotating the forward vector 270 degrees left
			# x' = x cos 270 - y sin 270; y' = x sin 270 + y cos 270
			# x' = x * 0 - y * -1; y' = x * -1 + y * 0
			rightVector = Geom::Vector3d.new(forwardVector.y, (-1 * forwardVector.x), 0)
			movementVector += rightVector
		end
		# Up
		if ((@FPSNav_moveKeyFlags & 0b100000) != 0)
			movementVector.z += 1# += Geom::Vector3d.new(0,0,1) # Up vector
		end
		# Down
		if ((@FPSNav_moveKeyFlags & 0b010000) != 0)
			movementVector.z -= 1#= Geom::Vector3d.new(0,0,-1) # Down vector
		end
		# Make a transform so we can move the camera and the view target
		# both however far forward
		if @FPS_accel == nil
			@FPS_accel = 1 + @@Chatham_FPSNav_accelerationUnit
		else
			@FPS_accel += @@Chatham_FPSNav_accelerationUnit
		end
		movementVector.length = @@Chatham_FPSNav_moveSpeed / 4.0 * @FPS_accel	# 10

		## Clamp the movement speed
		if (movementVector.length > @@Chatham_FPSNav_maxSpeed)
			movementVector.length = @@Chatham_FPSNav_maxSpeed
		end
		# Then create the move transform
		movementTransform = Geom::Transformation.new(movementVector)

		# Make sure we have the freshest camera data
		# See if we can replace all the @FPSNav variables with sceneCamera....
		sceneCamera = @FPSNav_currentView.camera
		@FPSNav_eye = sceneCamera.eye
		@FPSNav_target = sceneCamera.target
		#Now move those values
		@FPSNav_eye.transform!(movementTransform)
		@FPSNav_target.transform!(movementTransform)
		# Finally, change the camera
		@FPSNav_currentView.camera.set(@FPSNav_eye, @FPSNav_target, movementUp)

		# And show the eye height
		Sketchup.vcb_value = @FPSNav_eye.z;
	end

	#Cheap attempt at MouseLook
	#Get our mouse coordinates every time the mouse moves
	def onMouseMove(flags, x, y, view)
		if (@FPSNav_mouseClickedFlag != 0)
			@FPSNav_mouseX = x
			@FPSNav_mouseY = y
		end
	end
	#Double Clicking with left mouse button toggles mouselook
	def onLButtonDoubleClick(flags, x, y, view)
		if (@FPSNav_mouseClickedFlag == 0)
			@FPSNav_mouseClickedFlag = 2
		elsif ( @FPSNav_mouseClickedFlag == 2)
			@FPSNav_mouseClickedFlag = 0
		end
	end
	#Holding MLB down also enables mouselook
	def onLButtonDown(flags, x, y, view)
		@FPSNav_prevMouseX = x
		@FPSNav_prevMouseY = y
		@FPSNav_mouseX = x
		@FPSNav_mouseY = y
		@FPSNav_mouseClickedFlag = 1
	end

	def onLButtonUp(flags, x, y, view)
		if (@FPSNav_mouseClickedFlag == 1)
			@FPSNav_mouseClickedFlag = 0
		end
	end

	# If we leave the view, stop mouseLooking and go back to normal speed
	def onMouseLeave(view)
		@FPSNav_mouseClickedFlag = 0
	end

	# For this tool, allow vcb text entry while the tool is active.
	def enableVCB?
		return true
	end

	# If the user enters something in the VCB, if it's a number, set eye height to that
	def onUserText(text, view)
		begin
			@FPSNav_eye.z = text.to_l
		rescue
			# Error parsing the text
			UI.beep
			puts "Cannot convert #{text} to a Length"
		end

		@FPSNav_currentView.camera.set(@FPSNav_eye, @FPSNav_target, @FPSNav_up)
		puts text

		Sketchup.vcb_value = @FPSNav_eye.z;
	end

	# This gets run every frame, points the camera toward the mouse cursor if doing mouse look, and moves the camera if holding a key
	# To implement mouseLook, we grab the cursor position from the screen,
	# compare that to where the cursor was last frame, then rotate the eye target
	# a certain amount based on those variables
	def update
		if (@FPSNav_movingFlag == 1)
			moveCamera
		end
		# First off, only do this if we're clicking
		if (@FPSNav_mouseClickedFlag != 0)
			# Make sure we have the most recent data for camera target and eye position
			sceneCamera = @FPSNav_currentView.camera
			@FPSNav_eye = sceneCamera.eye
			@FPSNav_target = sceneCamera.target
			# Control our camera.up - if we're looking straight down, work around that
			# We'll use this to calculate camera position
			forwardVector = @FPSNav_target - @FPSNav_eye
			# Eliminate the z component
			forwardVector.z = 0
			mouseLookUp = @FPSNav_up
			if (forwardVector.length == 0)
				puts 'vertical'
				mouseLookUp.y = 0.1
			end

			# We'll do the X rotation first (rotating around the eye, on a verical axis, A radians
			verticalAxis = Geom::Vector3d.new(0,0,1)
			radiansToRotate = Float(@FPSNav_prevMouseX - @FPSNav_mouseX) / @@Chatham_FPSNav_xSensitivity
			xRotationTransformation = Geom::Transformation.rotation(@FPSNav_eye, verticalAxis, radiansToRotate)
			@FPSNav_target.transform!(xRotationTransformation)

			# Now the Y axis
			# The vector to rotate around is perpendicular to the vector we're viewing on
			forwardVector = @FPSNav_target - @FPSNav_eye
			forwardVector.z = 0
			horizontalAxis = Geom::Vector3d.new((-1 * forwardVector.y), forwardVector.x, 0)
			horizontalAxis = sceneCamera.xaxis
			radiansToRotate = Float(@FPSNav_mouseY - @FPSNav_prevMouseY ) / @@Chatham_FPSNav_ySensitivity
			# And limit this axis
			yRotationTransformation = Geom::Transformation.rotation(@FPSNav_eye, horizontalAxis, -radiansToRotate)
			tempTarget = @FPSNav_target.transform(yRotationTransformation)
			vector1 = tempTarget - @FPSNav_eye
			angle = vector1.angle_between(@FPSNav_up)
			if (angle > 0 && angle < 3)
				@FPSNav_target.transform!(yRotationTransformation)
			end
			# Set the camera
			@FPSNav_currentView.camera.set(@FPSNav_eye, @FPSNav_target, mouseLookUp)
			# Finally, set the mouse position variables to be ready for next time
			@FPSNav_prevMouseX = @FPSNav_mouseX
			@FPSNav_prevMouseY = @FPSNav_mouseY
		end #End of if (mouseClickedFlag) statement
	end

	# Create the WebDialog instance
	def self.fpsNavOptions
		my_dialog = UI::WebDialog.new("FPSNav", false, "FPSNav", 260, 300, 200, 200, true)

		# Attach an action callback
		my_dialog.add_action_callback("returnValues"){|fpsNav_dialog,valueList|
			setValues(valueList)
			my_dialog.close()
		}

		my_dialog.add_action_callback("pageLoaded"){
			|fpsNav_dialog,action_name|
				#Send current values to the dialog
			speed = @@Chatham_FPSNav_moveSpeed.to_s
			xSensitivity = @@Chatham_FPSNav_xSensitivity.to_s
			ySensitivity = @@Chatham_FPSNav_ySensitivity.to_s
			my_dialog.execute_script("populateFields(" + speed + "," + xSensitivity +"," + ySensitivity +")")
		}

		my_dialog.add_action_callback("closeDialog"){|fpsNav_dialog, value| my_dialog.close()}

		# Find and show our html file
		html_path = Sketchup.find_support_file "FPSNavMenu.html" ,"Plugins/FPSNav"
		my_dialog.set_file(html_path)
		my_dialog.show()
	end

	def self.setValues(valuesString)
		valuesArray = valuesString.split(":")
		#Make sure we get sensible values in
		speed = valuesArray[0].to_f
		xSensitivity = valuesArray[1].to_i
		ySensitivity = valuesArray[2].to_i

		#Use the values and store them to the registry
		if (speed > 0 && speed < 50)
			@@Chatham_FPSNav_moveSpeed = speed
			@@Chatham_FPSNav_maxSpeed = speed
			Sketchup.write_default "Chatham_FPSNav", "Chatham_FPSNav_moveSpeed", @@Chatham_FPSNav_moveSpeed
		end
		if (xSensitivity >= @@SensitivityMin && xSensitivity <= @@SensitivityMax)
			@@Chatham_FPSNav_xSensitivity = xSensitivity
			Sketchup.write_default "Chatham_FPSNav", "Chatham_FPSNav_xSensitivity", @@Chatham_FPSNav_xSensitivity.to_s
		end
		if (ySensitivity >= @@SensitivityMin && ySensitivity <= @@SensitivityMax)
			@@Chatham_FPSNav_ySensitivity = ySensitivity
			Sketchup.write_default "Chatham_FPSNav", "Chatham_FPSNav_ySensitivity", @@Chatham_FPSNav_ySensitivity.to_s
		end
	end

	# This functions is just a shortcut for selecting the new tool
	def self.fpsNavTool
		#puts Sketchup.active_model.tools
		#Sketchup.active_model.select_tool Chatham_FPSNavigator.new
		Sketchup.active_model.tools.push_tool(Chatham_FPSNavigator.new)
	end

	# One time, go ahead and add the toolbar and menu options
	filename = File.basename(__FILE__)
	if(not file_loaded?(filename))
		# Register our tool in the Plugins and Tools menu
		add_separator_to_menu("Plugins")
		plugin_menu = UI.menu "Plugins"
		plugin_menu.add_item("FPSNav Options") {fpsNavOptions}
		add_separator_to_menu("Tools")
		plugin_menu = UI.menu "Tools"
		plugin_menu.add_item("FPSNav") {fpsNavTool}

		# This toolbar icon provides toolbar access to FPSNav
		toolbar = UI::Toolbar.new "FPSNav"
		cmd = UI::Command.new("FPSNav") {Sketchup.active_model.select_tool Chatham_FPSNavigator.new}
		cmd.small_icon = "FPSNavIcon.png"
		cmd.large_icon = "FPSNavIcon.png"
		cmd.tooltip = "First Person Shooter style Navigator"
		cmd.status_bar_text = "Use arrow keys or hold 'Shift' and use WASD to move, hold Left Click to look around, double click to lock in mouselook"
		cmd.menu_text = "FPS Navigator"
		toolbar = toolbar.add_item cmd
		toolbar.restore
	end
	file_loaded(filename)

end #End FPSNavigator class
