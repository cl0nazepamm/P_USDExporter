-- Author: Clone.
macroScript PowerUSDReassemble
category:"CloneTools"
toolTip:"Reassemble USD Stage from exported files"
buttonText:"Clone PowerUSD Reassemble"
(
	rollout rReassemble "PowerUSD Reassemble" width:280
	(
		bitmap bmp_logo "Logo" fileName:"" height:50 width:240 align:#center

		edittext edt_dir "Export Dir:" fieldWidth:220 readOnly:true
		button btn_browse "Browse..." width:220 height:24

		group "Time Range"
		(
			spinner spn_startFrame "Start:" range:[-10000, 10000, 0] type:#integer fieldWidth:50 across:2
			spinner spn_endFrame "End:" range:[-10000, 10000, 100] type:#integer fieldWidth:50
			spinner spn_fps "FPS:" range:[1, 120, 24] type:#integer fieldWidth:50
		)

		group "Assembly"
		(
			checkbox chk_rootPrim "Root Prim" checked:false tooltip:"Wrap everything under a root prim.\nUncheck to place assets at stage root."
			edittext edt_defaultPrim "Default Prim:" text:"World" fieldWidth:180 enabled:false tooltip:"Top-level assembly prim name."
			checkbox chk_inlineCameras "Inline Cameras" checked:true tooltip:"Write camera data directly into .usda stage.\nUncheck to use USD references for cameras."
		)

		label lbl_status "" align:#left
		button btn_dryHierarchy "GENERATE _HIERARCHY" width:220 height:24 enabled:false tooltip:"Generate _hierarchy.txt from current scene selection.\nRequires objects to be selected."
		button btn_assemble "REASSEMBLE STAGE" width:220 height:40 enabled:false

		on rReassemble open do
		(
			spn_startFrame.value = animationRange.start.frame as integer
			spn_endFrame.value = animationRange.end.frame as integer
			spn_fps.value = frameRate as integer

			local iconsDir = GetDir #userIcons
			local logoPath = iconsDir + "\\PowerUSD\\powerusd_logo.png"
			if doesFileExist logoPath do bmp_logo.fileName = logoPath
		)

		on chk_rootPrim changed state do
			edt_defaultPrim.enabled = state

		on btn_browse pressed do
		(
			local dir = getSavePath caption:"Select Export Directory"
			if dir != undefined do
			(
				edt_dir.text = dir

				-- Check for USD files
				local usdFiles = getFiles (dir + "\\*.usd") + getFiles (dir + "\\*.usda") + getFiles (dir + "\\*.usdc")
				local hasHierarchy = doesFileExist (dir + "\\_hierarchy.txt")

				if usdFiles.count == 0 then
				(
					lbl_status.text = "No USD files found."
					btn_dryHierarchy.enabled = true
					btn_assemble.enabled = false
				)
				else
				(
					local msg = (usdFiles.count as string) + " USD file(s)"
					if hasHierarchy then msg += " + hierarchy"
					else msg += " (flat mode)"
					lbl_status.text = msg
					btn_dryHierarchy.enabled = true
					btn_assemble.enabled = true
				)
			)
		)

		on btn_dryHierarchy pressed do
		(
			if edt_dir.text == "" do (messageBox "Select a directory first."; return false)

			local rawSelection = selection as array
			if rawSelection.count == 0 do (messageBox "Select objects in the scene first."; return false)

			local scriptsDir = (getDir #userScripts) + "/CloneTools/"
			local builderPath = scriptsDir + "Clone_USD_HierarchyBuilder.ms"
			if not doesFileExist builderPath do
			(
				messageBox "Clone_USD_HierarchyBuilder.ms not found in CloneTools."
				return false
			)

			fileIn builderPath

			local exportSets = buildAdvancedExportSets rawSelection edt_dir.text writeMetadata:false
			exportSets = bundleCameraTargetsInExportSets exportSets
			writeHierarchyMetadata exportSets edt_dir.text
			printHierarchyPreview exportSets

			lbl_status.text = "_hierarchy.txt written (" + exportSets.count as string + " entries)"
			messageBox ("_hierarchy.txt written with " + exportSets.count as string + " entries.") title:"PowerUSD"
		)

		on btn_assemble pressed do
		(
			if edt_dir.text == "" do (messageBox "Select a directory first."; return false)

			local scriptsDir = (getDir #userScripts) + "/CloneTools/"
			local assemblerPath = scriptsDir + "Clone_USD_StageAssembler.py"

			if not doesFileExist assemblerPath do
			(
				messageBox "Clone_USD_StageAssembler.py not found in CloneTools."
				return false
			)

			local safeDir = substituteString edt_dir.text "'" "\\'"
			python.Execute ("_powerusd_export_dir = r'" + safeDir + "'")

			if chk_rootPrim.checked then
			(
				local primName = trimRight (trimLeft edt_defaultPrim.text)
				if primName != "" then
				(
					local safePrim = substituteString primName "'" "\\'"
					python.Execute ("_powerusd_default_prim = r'" + safePrim + "'")
				)
				else
				(
					python.Execute "_powerusd_default_prim = None"
				)
			)
			else
			(
				python.Execute "_powerusd_default_prim = None"
			)

			python.Execute ("_powerusd_start_frame = " + (spn_startFrame.value as integer) as string)
			python.Execute ("_powerusd_end_frame = " + (spn_endFrame.value as integer) as string)
			python.Execute ("_powerusd_fps = " + (spn_fps.value as integer) as string)

			if chk_inlineCameras.checked then
				python.Execute "_powerusd_inline_cameras = True"
			else
				python.Execute "_powerusd_inline_cameras = False"

			python.ExecuteFile assemblerPath

			lbl_status.text = "Reassembly complete."
			messageBox "Stage reassembled." title:"PowerUSD"
		)
	)

	createDialog rReassemble
)
