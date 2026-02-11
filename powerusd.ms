-- Author: Clone.
macroScript PowerUSDExport
category:"CloneTools"
toolTip:"Batch Export Selected to USD with UI"
buttonText:"Clone PowerUSD UI"
(
	persistent global g_PowerUSD_lastDir

	-- Load shared hierarchy builder (ExportNodeData, buildAdvancedExportSets, writeHierarchyMetadata, etc.)
	fileIn ((getDir #userScripts) + "/CloneTools/Clone_USD_HierarchyBuilder.ms")

	fn captureViewportThumb nodes filePath thumbSize:256 =
	(
		local oldRenderer = renderers.current
		local oldBgColor = backgroundColor
		local oldUseEnvMap = useEnvironmentMap

		local nodeSet = for n in nodes collect n
		local hiddenObjs = for o in objects where not o.isHidden and findItem nodeSet o == 0 collect o
		hide hiddenObjs

		select nodes
		max zoomext sel

		renderers.current = Quicksilver_Hardware_Renderer()
		backgroundColor = color 0 0 0 0
		useEnvironmentMap = false

		local thumb = render outputSize:[thumbSize, thumbSize] vfb:off quiet:true

		pngio.setAlpha true
		thumb.filename = filePath
		save thumb
		close thumb

		renderers.current = oldRenderer
		backgroundColor = oldBgColor
		useEnvironmentMap = oldUseEnvMap

		unhide hiddenObjs
		return true
	)

	fn performBatchExport exportSets outDir useOrigin useThumbnails startFrame endFrame fps =
	(
		if exportSets.count > 0 then
		(
			local abortBatch = false

			undo "Batch USD Export" on
			(
				with redraw off
				(
					for i = 1 to exportSets.count do
					(
						if not abortBatch do
						(
							local item = exportSets[i]
							if item.rootNodes == undefined or item.rootNodes.count == 0 then
							(
								format "Skipping metadata-only set '%'\n" item.exportName
								continue
							)

							local exportDir = outDir
							if item.subFolder != undefined and item.subFolder != "" then
							(
								exportDir = outDir + "\\" + item.subFolder
								makeDir exportDir all:true
							)

							local filePath = exportDir + "\\" + item.exportName + ".usd"
							local thumbPath = exportDir + "\\" + item.exportName + "_thumb.png"
							local originalPos = [0, 0, 0]
							local moved = false

							select item.rootNodes

							try
							(
								if useOrigin and item.moveRoot != undefined then
								(
									originalPos = item.moveRoot.pos
									item.moveRoot.pos = [0, 0, 0]
									moved = true
								)

								local result = false

								if i == 1 then
								(
									result = exportFile filePath selectedOnly:true
									if result == false do abortBatch = true
								)
								else
								(
									result = exportFile filePath #noPrompt selectedOnly:true
								)

								if useThumbnails and result != false do
								(
									local lowerName = toLower item.exportName
									local skipThumb = (matchPattern lowerName pattern:"*_proxy*") or (matchPattern lowerName pattern:"*_guide*")
									if not skipThumb do
										captureViewportThumb item.rootNodes thumbPath
								)
							)
							catch
							(
								format "Error exporting '%': %\n" item.exportName (getCurrentException())
							)
							finally
							(
								if moved do item.moveRoot.pos = originalPos
							)
						)
					)
				)
			)

			return (not abortBatch)
		)
		return false
	)

	fn setAssemblerPythonVars outDir defaultPrimName startFrame endFrame fps inlineCameras:true =
	(
		local safeOutDir = substituteString outDir "'" "\\'"
		python.Execute ("_powerusd_export_dir = r'" + safeOutDir + "'")

		local primName = ""
		if defaultPrimName != undefined do primName = trimRight (trimLeft defaultPrimName)
		if primName != "" then
		(
			local safePrim = substituteString primName "'" "\\'"
			python.Execute ("_powerusd_default_prim = r'" + safePrim + "'")
		)
		else
		(
			python.Execute "_powerusd_default_prim = None"
		)

		python.Execute ("_powerusd_start_frame = " + (startFrame as integer) as string)
		python.Execute ("_powerusd_end_frame = " + (endFrame as integer) as string)
		python.Execute ("_powerusd_fps = " + (fps as integer) as string)

		if inlineCameras then
			python.Execute "_powerusd_inline_cameras = True"
		else
			python.Execute "_powerusd_inline_cameras = False"
	)

	rollout rPowerUSD "Power USD Exporter" width:260
	(
		bitmap bmp_logo "Logo" fileName:"" height:50 width:240 align:#center

		group "Time Range"
		(
			spinner spn_startFrame "Start:" range:[-10000, 10000, 0] type:#integer fieldWidth:50 across:2
			spinner spn_endFrame "End:" range:[-10000, 10000, 100] type:#integer fieldWidth:50
			spinner spn_fps "FPS:" range:[1, 120, 24] type:#integer fieldWidth:50
		)

		group "Export Mode"
		(
			radiobuttons rdo_mode labels:#("Simple", "Advanced") columns:2 default:1 \
				tooltip:"Simple: Export hierarchies as-is, move to origin option.\nAdvanced: P_USDparamobj hierarchy detection, variants, purposes."
			checkbox chk_advSingle "Single Export (Advanced)" checked:false \
				tooltip:"Advanced only. Exports only selected Advanced units for incremental updates."
			label lbl_modeInfo "" align:#left
		)

		group "Grouping (Simple Mode)"
		(
			checkbox chk_layers "By Layers" checked:false tooltip:"One USD file per Layer."
			checkbox chk_hierarchy "By Hierarchies" checked:true tooltip:"One USD file per Hierarchy Root."
		)

		group "Transform (Simple Mode)"
		(
			checkbox chk_origin "Move to Origin" checked:false tooltip:"Temporarily moves root to 0,0,0 for export."
		)

		group "Options"
		(
			checkbox chk_thumbnail "Generate Thumbnails" checked:false
		)

		group "Assembler"
		(
			checkbox chk_autoAssemble "Auto Assemble Stage" checked:true tooltip:"Create .usda stage referencing all exports.\nRebuilds hierarchy from metadata."
			checkbox chk_rootPrim "Root Prim" checked:false tooltip:"Wrap everything under a root prim.\nUncheck to place assets at stage root."
			edittext edt_defaultPrim "Default Prim:" text:"World" fieldWidth:140 tooltip:"Top-level assembly prim name (e.g. World)."
			checkbox chk_inlineCameras "Inline Cameras" checked:true tooltip:"Write camera data directly into .usda stage.\nUncheck to use USD references for cameras."
		)

		button btn_export "EXPORT SELECTED" width:220 height:40 highlightColor:(color 0 200 0)
		button btn_export_sets "EXPORT SELECTION SETS" width:220 height:30
		button btn_addUSDProps "Add USD Properties" width:220 height:24 tooltip:"Add USD Attribute Holder to selected objects (P_USDparamobj)."
		button btn_genProxy "Generate Cube Proxies" width:220 height:24 tooltip:"Create bounding box proxies for selected _RENDER objects."

		fn updateModeUI =
		(
			local isSimple = (rdo_mode.state == 1)
			chk_layers.enabled = isSimple
			chk_hierarchy.enabled = isSimple
			chk_origin.enabled = isSimple
			chk_advSingle.enabled = (not isSimple)
			if isSimple do chk_advSingle.checked = false

			if isSimple then
				lbl_modeInfo.text = "Exports hierarchies as-is."
			else
				lbl_modeInfo.text = "P_USDparamobj -> separate USD files (optional single export)."
		)

		on rdo_mode changed state do updateModeUI()

		on chk_layers changed state do
			if state do chk_hierarchy.checked = false

		on chk_hierarchy changed state do
			if state do chk_layers.checked = false

		on chk_rootPrim changed state do
			edt_defaultPrim.enabled = state

		on rPowerUSD open do
		(
			spn_startFrame.value = animationRange.start.frame as integer
			spn_endFrame.value = animationRange.end.frame as integer
			spn_fps.value = frameRate as integer

			local iconsDir = GetDir #userIcons
			local logoPath = iconsDir + "\\PowerUSD\\powerusd_logo.png"
			if doesFileExist logoPath do bmp_logo.fileName = logoPath

			updateModeUI()
		)

		on btn_addUSDProps pressed do
		(
			local attrDefPath = (getDir #userScripts) + "/CloneTools/Clone_USD_AttributeDef.ms"
			if doesFileExist attrDefPath then
			(
				fileIn attrDefPath
				if selection.count > 0 then
				(
					for obj in selection do addUSDProperties obj
					format "Added USD Properties to % object(s)\n" selection.count
				)
				else messageBox "No objects selected."
			)
			else messageBox "Clone_USD_AttributeDef.ms not found."
		)

		on btn_genProxy pressed do
		(
			if selection.count == 0 then (messageBox "No objects selected."; return false)

			local attrDefPath = (getDir #userScripts) + "/CloneTools/Clone_USD_AttributeDef.ms"
			if doesFileExist attrDefPath do fileIn attrDefPath

			local created = 0
			local renderObjs = for obj in selection where (matchPattern obj.name pattern:"*_RENDER*") collect obj

			if renderObjs.count == 0 then
			(
				messageBox "No _RENDER objects found in selection."
				return false
			)

			undo "Generate Cube Proxies" on
			(
				for obj in renderObjs do
				(
					local proxyName = substituteString obj.name "_RENDER" "_PROXY"
					if proxyName == obj.name do
						proxyName = substituteString obj.name "_render" "_PROXY"

					if getNodeByName proxyName != undefined do continue

					local bMin = obj.min
					local bMax = obj.max
					local bSize = bMax - bMin
					local bCenter = (bMin + bMax) / 2.0

					local proxyBox = Box length:bSize.y width:bSize.x height:bSize.z pos:[bCenter.x, bCenter.y, bMin.z]
					proxyBox.name = proxyName
					proxyBox.wirecolor = color 0 180 255

					if obj.parent != undefined do proxyBox.parent = obj.parent

					addUSDProperties proxyBox

					created += 1
				)
			)

			format "Generated % cube proxy(s) with USD Properties\n" created
		)

		on btn_export_sets pressed do
		(
			if selectionSets.count == 0 then (messageBox "No Selection Sets found."; return false)

			if g_PowerUSD_lastDir == undefined do g_PowerUSD_lastDir = (getDir #export)
			local outDir = getSavePath caption:"Select Output Directory" initialDir:g_PowerUSD_lastDir
			if outDir == undefined do return false
			g_PowerUSD_lastDir = outDir

			local scriptsDir = (getDir #userScripts) + "/CloneTools/"
			if doesFileExist (scriptsDir + "Clone_USD_CleanStruct.py") do python.ExecuteFile (scriptsDir + "Clone_USD_CleanStruct.py")
			if doesFileExist (scriptsDir + "Clone_USD_usdWrapper.py") do python.ExecuteFile (scriptsDir + "Clone_USD_usdWrapper.py")
			if doesFileExist (scriptsDir + "Clone_USD_PropertiesChaser.py") do python.ExecuteFile (scriptsDir + "Clone_USD_PropertiesChaser.py")

			local exportSets = #()
			for i = 1 to selectionSets.count do
			(
				local setName = getNamedSelSetName i
				local setNodes = for obj in selectionSets[i] collect obj
				if setNodes.count > 0 do
					append exportSets (ExportNodeData exportName:setName rootNodes:setNodes moveRoot:undefined subFolder:undefined parentName:undefined)
			)
			exportSets = partitionCamerasToSingleExport exportSets cameraFileName:"Cameras"
			exportSets = bundleCameraTargetsInExportSets exportSets

			local currentSel = selection as array
			local exportSuccess = performBatchExport exportSets outDir false chk_thumbnail.checked spn_startFrame.value spn_endFrame.value spn_fps.value

			if exportSuccess do
			(
				select currentSel
				if chk_autoAssemble.checked do
				(
					local assemblerPath = scriptsDir + "Clone_USD_StageAssembler.py"
					if doesFileExist assemblerPath do
					(
						setAssemblerPythonVars outDir (if chk_rootPrim.checked then edt_defaultPrim.text else "") spn_startFrame.value spn_endFrame.value spn_fps.value inlineCameras:chk_inlineCameras.checked
						python.ExecuteFile assemblerPath
					)
				)
			)
		)

		on btn_export pressed do
		(
			local rawSelection = selection as array
			if rawSelection.count == 0 then (messageBox "No objects selected."; return false)

			if g_PowerUSD_lastDir == undefined do g_PowerUSD_lastDir = (getDir #export)
			local outDir = getSavePath caption:"Select Output Directory" initialDir:g_PowerUSD_lastDir
			if outDir == undefined do return false
			g_PowerUSD_lastDir = outDir

			local scriptsDir = (getDir #userScripts) + "/CloneTools/"
			if doesFileExist (scriptsDir + "Clone_USD_CleanStruct.py") do python.ExecuteFile (scriptsDir + "Clone_USD_CleanStruct.py")
			if doesFileExist (scriptsDir + "Clone_USD_usdWrapper.py") do python.ExecuteFile (scriptsDir + "Clone_USD_usdWrapper.py")
			if doesFileExist (scriptsDir + "Clone_USD_PropertiesChaser.py") do python.ExecuteFile (scriptsDir + "Clone_USD_PropertiesChaser.py")

			local exportSets = #()
			local isAdvancedMode = (rdo_mode.state == 2)
			local shouldWriteHierarchyMeta = false

			-- MODE: Advanced (P_USDparamobj -> separate files, hierarchy from metadata)
			if isAdvancedMode then
			(
				if chk_advSingle.checked then
				(
					format "Advanced single export: hierarchy metadata file is not rewritten.\n"
					exportSets = buildAdvancedSingleExportSets rawSelection outDir writeMetadata:false
				)
				else
				(
					exportSets = buildAdvancedExportSets rawSelection outDir writeMetadata:false
					shouldWriteHierarchyMeta = true
				)
			)
			-- SIMPLE MODE: Layers (all objects on layer exported together, MaxUSD handles instancing)
			else if chk_layers.checked then
			(
				local layerNames = #()

				for obj in rawSelection do
				(
					local lName = obj.layer.name
					if findItem layerNames lName == 0 do append layerNames lName
				)

				for lName in layerNames do
				(
					local layer = LayerManager.getLayerFromName lName
					local layerNodes = #()
					layer.nodes &layerNodes

					-- Export all layer nodes together - MaxUSD handles instancing automatically
					format "  Layer '%': % objects\n" lName layerNodes.count
					append exportSets (ExportNodeData exportName:lName rootNodes:layerNodes moveRoot:undefined subFolder:undefined parentName:undefined)
				)
			)
			-- SIMPLE MODE: Hierarchies (entire hierarchy exported together, MaxUSD handles instancing)
			else if chk_hierarchy.checked then
			(
				local processedRoots = #()

				for obj in rawSelection do
				(
					local root = getHierarchyRoot obj
					if findItem processedRoots root == 0 do
					(
						append processedRoots root
						local fullTree = getAllDescendants root

						-- Export entire hierarchy together - MaxUSD handles instancing automatically
						format "  Hierarchy '%': % objects\n" root.name fullTree.count
						append exportSets (ExportNodeData exportName:root.name rootNodes:fullTree moveRoot:root subFolder:undefined parentName:undefined)
					)
				)
			)
			-- SIMPLE MODE: Standard (individual objects/groups, instances exported together)
			else
			(
				local groupsProcessed = #()
				local geometryObjects = #()
				local groupObjects = #()

				-- Separate groups from geometry
				for obj in rawSelection do
				(
					if isGroupMember obj then
					(
						local grpHead = obj
						while (isGroupMember grpHead) do grpHead = grpHead.parent
						if findItem groupsProcessed grpHead == 0 do
						(
							append groupsProcessed grpHead
							append groupObjects grpHead
						)
					)
					else if isGroupHead obj then
					(
						if findItem groupsProcessed obj == 0 do
						(
							append groupsProcessed obj
							append groupObjects obj
						)
					)
					else
					(
						append geometryObjects obj
					)
				)

				-- Add group exports
				for grp in groupObjects do
					append exportSets (ExportNodeData exportName:grp.name rootNodes:#(grp) moveRoot:grp subFolder:undefined parentName:undefined)

				-- Instance detection: group by baseObject, export ALL instances together
				local instanceGroups = groupByInstances geometryObjects
				format "Instance detection: found % unique base objects from % geometry objects\n" instanceGroups.count geometryObjects.count

				for group in instanceGroups do
				(
					local master = selectMasterInstance group
					-- Export ALL instances together - MaxUSD handles instancing automatically
					if group.count > 1 then
						format "  Instance group '%': % instances -> exporting together\n" master.name group.count

					append exportSets (ExportNodeData exportName:master.name rootNodes:group moveRoot:master subFolder:undefined parentName:undefined)
				)
			)

			exportSets = partitionCamerasToSingleExport exportSets cameraFileName:"Cameras"
			exportSets = bundleCameraTargetsInExportSets exportSets
			if shouldWriteHierarchyMeta and exportSets.count > 0 do writeHierarchyMetadata exportSets outDir

			local currentSel = selection as array
			-- Only apply move-to-origin in Simple mode
			local useOrigin = (not isAdvancedMode) and chk_origin.checked
			local exportSuccess = performBatchExport exportSets outDir useOrigin chk_thumbnail.checked spn_startFrame.value spn_endFrame.value spn_fps.value

			if exportSuccess do
			(
				select rawSelection
				if chk_autoAssemble.checked do
				(
					local assemblerPath = scriptsDir + "Clone_USD_StageAssembler.py"
					if doesFileExist assemblerPath do
					(
						setAssemblerPythonVars outDir (if chk_rootPrim.checked then edt_defaultPrim.text else "") spn_startFrame.value spn_endFrame.value spn_fps.value inlineCameras:chk_inlineCameras.checked
						python.ExecuteFile assemblerPath
					)
				)
				format "\n=== Export Complete ===\n"
			)
		)
	)

	createDialog rPowerUSD
)
