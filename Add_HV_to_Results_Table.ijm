/* This macro adds hardness, HV to the Results table
	Peter J. Lee NHMFL
	v200526 First Version
	v200609-11 Fixed unit from table error, now can embed scale in table, more careful about unit selection.
	v200730 Updated tableSetColumnValue function. v201130 set embedded row to row zero
	v211022 Updated color choices.
	v220606 Fixed NaN issue.
	v220607 Fixed row number issue. f1-3: updated colors.
	v230530 Saves settings.
	v230531 Uses ROI.getFeretPoints to generate primary Feret axis. Changed table column names to be more descriptive. F1: updated indexOf functions. F3: Updated getColorFromColorName function (012324).
	v260416-20	Added HV from indent dArea option.
	v260422	Replace HV from indent with Meyer Hardness, and added a plasticity Index, and SI options. g. Handles a wider variety of microns.
	v260423 Does not create an extra flat image if no overlay lines are drawn.
	v260424 New HVp measurement and applies user-entered YS and UTS formulae.
*/
macro "Add_HV_to_Results_Table" {
    macroL = "Add_HV_to_Results_Table_v260424b.ijm";
    requires("1.52m28"); /*Uses the new ROI.getFeretPoints released in 1.52m28 */
    saveSettings(); /* Required for restoreExit function */
	imageTitle = stripKnownExtensionFromString(getTitle);
    nTable = Table.size;
    if (nTable == 0) restoreExit("No Table to work with");
    tableTitle = Table.title;
    nROI = roiManager("count");
    if (nTable == 0) restoreExit("No Results Table to work with");
    if (nTable == nROI) ROIs = true;
    else ROIs = false; /* well might as well not be true if they don't match */
    selectWindow(tableTitle);
    if (isNaN(Table.get("Feret", 0)) || isNaN(Table.get("Feret2", 0))) needFeret = true;
    else needFeret = false;
    if (needFeret && nImages == 0) restoreExit("Goodbye, Feret measurements are needed but no images are open to generate them");
    /* 'Feret's Diameter - The longest distance between any two points along the selection boundary, also known as maximum caliper. Uses the Feret heading...MinFeret is the minimum caliper diameter.' https://imagej.net/docs/menus/analyze.html */
	availableUnits = newArray("mm", getInfo("micrometer.abbreviation"), "nm", "pm"); /* Just these acceptable units in this version but see below */
    scaleFactors = newArray(1, 1E6, 1E12, 1E18); /* Add to scale factors if available units is expanded */
    /* Check table for embedded scale */
    tableScale = false;
    pixelWidth = 1; /* no-scale flag */
    pixelHeight = 1; /* no-scale flag */
    unit = getInfo("micrometer.abbreviation"); /* just a holder */
	infoColor = "#006db0"; /* Honolulu blue */
	instructionColor = "#798541"; /* green_dark_modern (121, 133, 65) AKA Wasabi */
	infoWarningColor = "#ff69b4"; /* pink_modern AKA hot pink */
	infoFontSize = 13;
    if (Table.size != 0) {
        tablePW = Table.get("PixelWidth", 0); /* This value embedded in the table by some ASC macros */
        tablePAR = Table.get("PixelAR", 0); /* This value embedded in the table by some ASC macros */
        tableUnit = Table.getString("Unit", 0); /* This value embedded in the table by some ASC macros */
        tableTitle = Table.title;
        if (!isNaN(tablePW) && !isNaN(tablePAR) && tableUnit != "null") {
            tableScale = true;
            pixelWidth = parseFloat(tablePW); /* Make sure imported value is a number */
            pixelAR = parseFloat(tablePAR); /* Make sure imported value is a number  */
            pixelHeight = pixelWidth / pixelAR;
            unit = tableUnit;
        }
    }
    if (!tableScale && nImages != 0) getPixelSize(unit, pixelWidth, pixelHeight);
    if (pixelWidth == 1 || indexOfArray(availableUnits, unit, -1) < 0) {
        Dialog.create("Manual scale entry");
        Dialog.addMessage("No images open, or scale appears to be non-metric, please enter unit values", infoFontSize, infoWarningColor);
        Dialog.addNumber("pixel width", 1, 10, 10, "units");
        Dialog.addNumber("pixel height", 1, 10, 10, "units");
        Dialog.addChoice("units", availableUnits, availableUnits[1]);
        Dialog.show;
        if (Dialog.getRadioButton == "exit") exit;
        pixelWidth = Dialog.getNumber;
        pixelHeight = Dialog.getNumber;
        unit = Dialog.getChoice;
    }
    if (indexOfArray(availableUnits, unit, -1) < 0) exit("Sorry, no appropriate units available");
    pixelAR = pixelWidth / pixelHeight;
	if (unit == "um" || unit == "Âµm" || unit == "µm" || startsWith(unit, "micron")) unit = getInfo("micrometer.abbreviation");
    unitLabel = "\(" + unit + "\)";
    lcf = (pixelWidth + pixelHeight) / 2;
    sFI = indexOfArray(availableUnits, unit, -1);
    sF = scaleFactors[sFI];
	if (sF < 1) exit("No scale factor found for unit " + unit);
    sup2 = fromCharCode(0x00B2); /* superscript 2 */
	colorChoicesStd = newArray("red", "green", "blue", "cyan", "magenta", "yellow", "pink", "orange", "violet");
    colorChoicesMaterials = newArray("bronze", "antique_bronze", "brass", "dull_brass", "brick", "chrome", "copper", "aged_copper", "dusky_copper", "light_copper", "garnet", "burnished_gold", "gold", "slate_gray", "titanium", "vault_garnet", "plaza_brick", "vault_gold");
    colorChoicesMod = newArray("aqua_modern", "blue_accent_modern", "blue_dark_modern", "blue_modern", "blue_honolulu", "gray_modern", "green_dark_modern", "green_modern", "green_modern_accent", "green_spring_accent", "orange_modern", "pink_modern", "purple_modern", "red_modern", "tan_modern", "violet_modern", "yellow_modern");
    colorChoicesNeon = newArray("jazzberry_jam", "radical_red", "wild_watermelon", "outrageous_orange", "supernova_orange", "atomic_tangerine", "neon_carrot", "sunglow", "laser_lemon", "electric_lime", "screamin'_green", "magic_mint", "blizzard_blue", "dodger_blue", "shocking_pink", "razzle_dazzle_rose", "hot_magenta");
    colorChoices = Array.concat(colorChoicesStd, colorChoicesMaterials, colorChoicesMod, colorChoicesNeon);
    imageList = getList("image.titles");
    overlayN = Overlay.size;
    drawDiamond = false;
    Dialog.create("Provide Load and Set Scale to Match Results Table \(" + macroL + "\)");
    gLoad = parseInt(call("ij.Prefs.get", "asc.hv.load", 100));
    Dialog.addNumber("Provide load in g used for indentation", gLoad, 0, 10, "g");
    additionalMethods = newArray("HVp", "HV_Area_Deviation_Index", "HV\(GPa\)", "HVp\(GPa\)");
	methodPrefs = split(call("ij.Prefs.get", "asc.hv.methodChecks", "0, 0, 0, 0"), ",");
	Dialog.addMessage("In addition to conventional HV from indent diagonals the followint are optional:" +
		"\n   HVp: HV from projected area, Ap. For the Vickers diamond geometry As = 1.0785 * Ap" +
		"\n   Area Deviation \(Plasticity?\) Index: Ap / Ad,\n          where Ap = projected Area & Ad = Area calculated from diagonals" + 
		"\n   SI Units: HV\(p\) \(GPa\) = HV\(p\) * 9.80665 / 1000", infoFontSize, infoColor);
	Dialog.setInsets(-5, 20, 0);
	Dialog.addCheckboxGroup(2, 2, additionalMethods, methodPrefs);
    Dialog.addMessage("Optional overlay lines________________________________________________________", infoFontSize, infoColor);
    /* ROI Feret */
    if (overlayN > 0) {
        Dialog.setInsets(5, 0, -3);
        Dialog.addCheckbox("Remove the " + overlayN + " existing overlays?", true);
    }
    // Dialog.setInsets(5, 0, -3);
    Dialog.addMessage("Optional Primary Feret line", infoFontSize, instructionColor);
    iFC = indexOfArray(colorChoices, call("ij.Prefs.get", "asc.hv.feret.color", colorChoices[1]), 1);
    Dialog.addChoice("Primary Feret line color:", colorChoices, colorChoices[iFC]);
    feretROILineWidth = parseInt(call("ij.Prefs.get", "asc.hv.feret.width", 0), 0);
    Dialog.addNumber("Primary Feret line width \(0 = no line\)", feretROILineWidth, 0, 3, "pixels");
    /* ROI Feret 2 */
    // Dialog.setInsets(5, 0, -3);
    Dialog.addMessage("Optional Feret2 \(complimentary\) line", infoFontSize, instructionColor);
    iF2C = indexOfArray(colorChoices, call("ij.Prefs.get", "asc.hv.feret2.color", colorChoices[2]), 2);
    Dialog.addChoice("Feret2 \(complimentary\) line color:", colorChoices, colorChoices[iF2C]);
    feret2LineWidth = parseInt(call("ij.Prefs.get", "asc.hv.feret2.width", 0), 0);
    Dialog.addNumber("Feret2 \(complimentary\) line width \(0 = no line\)", feret2LineWidth, 0, 3, "pixels");
	Dialog.addCheckbox("Flatten image to embed overlay lines in RGB copy of image \(ignored if line widths set to zero\)?", call("ij.Prefs.get", "asc.hv.flatImage", true));
	Dialog.addMessage("Yield Strength (\YS\) and Ultimate Tensile Strength \(UTS\) estimates_________________", infoFontSize, infoColor);
	estimates = newArray("YS", "UTS");
	estPrefs = split(call("ij.Prefs.get", "asc.hv.estChecks", "0, 0"), ",");
	Dialog.setInsets(5, 20, 0);
	Dialog.addCheckboxGroup(1, 2, estimates, estPrefs);
	Dialog.addMessage("   Please use the same format: A + B * HV if you want to replace with your own values" +
		"\n   For instance for Cu \[Krishna et al. DOI: 10.1155/2013/352578\]" + 
		" YS = 0 + 2.874 * HV, UTS = 0 + 3.353 * HV" +
		"\n   Default equations used are for steels as suggested by Pavlina and Tyne doi: 10.1007/s11665-008-9225-5", infoFontSize, instructionColor);
	fYS = call("ij.Prefs.get", "asc.hv.fYS", "-90.7 + 2.876 * HV");
	if (indexOf(fYS, "+") < 0 ) fYS = "-90.7 + 2.876 * HV";
	fUTS = call("ij.Prefs.get", "asc.hv.fUTS", "-99.8 + 3.734 * HV");
	if (indexOf(fYS, "+") < 0 ) fYS = "-99.8 + 3.734 * HV";
	Dialog.addString("Yield Strength Formula", fYS, 20);
	Dialog.addString("Ultimate Tensile Strength Formula", fUTS, 20);
	Dialog.setInsets(10, 20, 0);
	if (pixelAR != 1) Dialog.addMessage("Aspect pixels, average pixel size of " + lcf + " " + unit + " used", infoFontSize, instructionColor);
    if (unit != "mm") Dialog.addMessage("Image scale in " + unit + ", so the mm" + sup2 + " scale factor used is " + sF, infoFontSize, infoWarningColor);
    if (!tableScale) Dialog.addCheckbox("The Results table does not include the scale; do you want to add scale and unit columns?", true);
    Dialog.show;
    gLoad = Dialog.getNumber;
    if (gLoad >= 0) call("ij.Prefs.set", "asc.hv.load", gLoad);
	hVP = Dialog.getCheckbox();
	indexAD = Dialog.getCheckbox();
	hVSI = Dialog.getCheckbox();
	hVPSI = Dialog.getCheckbox();
	call("ij.Prefs.set", "asc.hv.methodChecks", "" + hVP + "," + indexAD + "," + hVSI + "," + hVPSI);
    /* ROI Feret line */
    if (overlayN > 0) remOverlays = Dialog.getCheckbox();
    else remOverlays = false;
    feretROILineColor = Dialog.getChoice();
    call("ij.Prefs.set", "asc.hv.feret.color", feretROILineColor);
    feretROILineWidth = Dialog.getNumber();
    call("ij.Prefs.set", "asc.hv.feret.width", feretROILineWidth);
    /* ROI Feret 2 line*/
    feret2LineColor = Dialog.getChoice();
    call("ij.Prefs.set", "asc.hv.feret2.color", feret2LineColor);
    feret2LineWidth = Dialog.getNumber();
    call("ij.Prefs.set", "asc.hv.feret2.width", feret2LineWidth);
	flatImage = Dialog.getCheckbox();
	call("ij.Prefs.set", "asc.hv.flatImage", flatImage);
	if (feretROILineWidth == 0 && feret2LineWidth == 0) flatImage = false; /* No overlay lines to embed */
	estYS = Dialog.getCheckbox();
	estUTS = Dialog.getCheckbox();
	call("ij.Prefs.set", "asc.hv.estChecks", estYS + "," + estUTS);
	fYS = Dialog.getString();
	call("ij.Prefs.set", "asc.hv.fYS", fYS);
	fUTS = Dialog.getString();
	call("ij.Prefs.set", "asc.hv.fUTS", fUTS);
    if (!tableScale){
		if (Dialog.getCheckbox()){
			tableSetColumnValue("PixelWidth", pixelWidth);
			tableSetColumnValue("PixelAR", pixelAR);
			tableSetColumnValue("Unit", unit);
		}
    }
	if (feretROILineWidth > 0)  drawDiamond = true;
    if (remOverlays) run("Remove Overlay");
    tableSetColumnValue("HV_load_g", gLoad);
    avgFerets_mm = newArray(nTable);
	if (needFeret) {
		if (!ROIs) restoreExit("Sorry, this macro needs ROIs to generate ROI_Feret and Feret2 \(complimentary Feret\) values");
		else {
			for (i = 0; i < nROI; i++) {
				if (i % 5 == 0) showProgress(i / nROI);
				roiManager("select", i);
				Roi.getFeretPoints(x, y);
				/* The minFeret is not needed here but is added in case it is useful elsewhere */
				Table.set("MinFeretX", i, x[2]);
				Table.set("MinFeretY", i, y[2]);
				Table.set("MinFeretX2", i, d2s(round(x[3]), 0));
				Table.set("MinFeretY2", i, d2s(round(y[3]), 0));
				/* The macro uses the Feret and complimentary Feret (called Feret2 here) to help generate the indent surface area */
				Table.set("FeretX", i, x[0]);
				Table.set("FeretY", i, y[0]);
				Table.set("FeretX2", i, x[1]);
				Table.set("FeretY2", i, y[1]);
				feretD = lcf * sqrt(pow(x[0] - x[1], 2) + pow(y[0] - y[1], 2));
				Table.set("Feret", i, feretD);
				minFeretD = lcf * sqrt(pow(x[2] - x[3], 2) + pow(y[2] - y[3], 2));
				Table.set("MinFeret", i, minFeretD);
				// Table.set("AR_Feret",i,feretD/minFeretD);
				Table.update;
				Roi.getCoordinates(xPoints, yPoints);
				nPoints = lengthOf(xPoints);
				/* Now determine complimentary Feret (NOT the min Feret) */
				maxCombinedDist = 0;
				/* Find first Feret2 point as the furthest ROI coordinate from the ROI-Feret coordinates */
				for (j = 0; j < nPoints; j++) {
					combinedDist = (sqrt(pow(xPoints[j] - x[0], 2) + pow(yPoints[j] - y[0], 2))) + (sqrt(pow(xPoints[j] - x[1], 2) + pow(yPoints[j] - y[1], 2)));
					if (combinedDist > maxCombinedDist) {
						maxCombinedDist = combinedDist;
						feret2X = xPoints[j];
						feret2Y = yPoints[j];
					}
				}
				Table.set("Feret2X", i, feret2X);
				Table.set("Feret2Y", i, feret2Y);
				feret2 = 0;
				/* Find the 2nd Feret2 point as the most distant from the first */
				for (j = 0; j < nPoints; j++) {
					f2Dist = sqrt(pow(xPoints[j] - feret2X, 2) + pow(yPoints[j] - feret2Y, 2));
					if (f2Dist > feret2) {
						feret2 = f2Dist;
						feret2X2 = xPoints[j];
						feret2Y2 = yPoints[j];
					}
				}
				Table.set("Feret2X2", i, feret2X2);
				Table.set("Feret2Y2", i, feret2Y2);
				feret2 *= lcf;
				Table.set("Feret2", i, feret2);
				// Table.set("AR_ROIFeret",i,feretROI/feret2);
				Table.update;
			}
		}
	}
	if (feretROILineWidth > 0) {
		setColorFromColorName(feretROILineColor);
		for (i = 0; i < nROI; i++) {
			setLineWidth(feretROILineWidth);
			/* need to recall from Table if the values already exit */
			Overlay.drawLine(Table.get("FeretX", i), Table.get("FeretY", i), Table.get("FeretX2", i), Table.get("FeretY2", i));
			Overlay.show;
		}
	}
	if (feret2LineWidth > 0) {
		setColorFromColorName(feret2LineColor);
		for (i = 0; i < nROI; i++) {
			setLineWidth(feret2LineWidth);
			Overlay.drawLine(Table.get("Feret2X", i), Table.get("Feret2Y", i), Table.get("Feret2X2", i), Table.get("Feret2Y2", i));
			Overlay.show;
		}
	}
	Table.applyMacro("FeretMaxCompAvg = (Feret+Feret2)/2");
	if (!isNaN(Table.get("Feret", 0)) && !isNaN(Table.get("Feret2", 0))) Table.applyMacro("FeretMaxAR = Feret/Feret2");
	if (!isNaN(Table.get("FeretMaxCompAvg", 0))) avgFerets = Table.getColumn("FeretMaxCompAvg");
	else exit("Could not find column FeretMaxCompAvg");
	if (unit != "mm" && sF >= 1){
		avgFerets_mm = newArray();
		for (i = 0; i < nTable; i++) avgFerets_mm[i] = avgFerets[i] * sF;
		Table.set("FeretMaxCompAvg_mm", i, avgFerets_mm[i]);
	}
	surfAreaF = 0.002 * sF * sin(68 * PI / 180) * gLoad; /* Need to convert g to kg and d to diamond indent surface area and thus kgf/mm² */
	hVs = newArray();
	colHV = "HV_" + gLoad + "g";
    for (i = 0; i < nTable; i++) {
		hVs[i] = surfAreaF / (pow(avgFerets[i], 2));
		Table.set(colHV, i, hVs[i]);
		if (hVSI) Table.set("HV\(GPa\)", i, hVs[i] * 0.00980665);
    }
	if (estYS){
		fYS = replace(fYS, "HV", colHV);
		IJ.log("YS estimated from: " + fYS);
		Table.applyMacro("YS_MPa = " + fYS);
		if (Table.columnExists("YS\(MPa\)")) Table.deleteColumn("YS\(MPa\)");
		Table.renameColumn("YS_MPa", "YS\(MPa\)");
	}
	if (estUTS){
		fUTS = replace(fUTS, "HV", colHV);
		IJ.log("UTS estimated from: " + fUTS);
		Table.applyMacro("UTS_MPa = " + fUTS);
		if (Table.columnExists("UTS\(MPa\)")) Table.deleteColumn("UTS\(MPa\)");
		Table.renameColumn("UTS_MPa", "UTS\(MPa\)");
	}
	if (hVP || indexAD || hVPSI) dAreas = Table.getColumn("Area");
	if (hVP || hVPSI){
		projAreaF = 0.001075 * sF * gLoad;
		hVPs = newArray();
		for (i = 0; i < nTable; i++){
			hVPs[i] = projAreaF / dAreas[i];
			if (hVP) Table.set("HVp_" + gLoad + "g", i, hVPs[i]);
			if (hVPSI) Table.set("HVp\(GPa\)", i, hVPs[i] * 0.00980665);
		}
	}
	if (indexAD){
		for (i = 0; i < nTable; i++) {
			indexAD = dAreas[i] / (pow(avgFerets[i], 2) / 2);
			Table.set("HV_AreaDevIndex", i, indexAD);
		}
	}	
    run("Select None");
    roiManager("deselect");
	if (flatImage){
		run("Flatten");
		rename(imageTitle + "_HV-lines");
	}
    setBatchMode("exit and display");
    restoreSettings(); /* Restore previous settings before exiting */
    beep(); wait(200); beep(); wait(200); beep(); wait(300); beep();
    showStatus("HV macro finished: " + nResults + " line\"s\" drawn");
    call("java.lang.System.gc");
}
/*
		   ( 8(|)	( 8(|)	Functions	@@@@@:-)	@@@@@:-)
   */

function indexOfArray(array, value,
    default) {
    /* v190423 Adds "default" parameter (use -1 for backwards compatibility). Returns only first found value
    	v230902 Limits default value to array size */
    index = minOf(lengthOf(array) - 1,
        default);
    for (i = 0; i < lengthOf(array); i++) {
        if (array[i] == value) {
            index = i;
            i = lengthOf(array);
        }
    }
    return index;
}

function getColorArrayFromColorName(colorName) {
    /* v180828 added Fluorescent Colors
       v181017-8 added off-white and off-black for use in gif transparency and also added safe exit if no color match found
       v191211 added Cyan
       v211022 all names lower-case, all spaces to underscores v220225 Added more hash value comments as a reference v220706 restores missing magenta
       v230130 Added more descriptions and modified order.
       v230908: Returns "white" array if not match is found and logs issues without exiting.
       v240123: Removed duplicate entries: Now 53 unique colors.
       v240709: Added 2024 FSU-Branding Colors. Some reorganization. Now 60 unique colors.
       v260202: Added 12 (mostly metallic) "Materials" colors. Now 72 unique colors.
       v260213: red_n_modern becomes red_modern and old red_modern becomes brick;
    */
    functionL = "getColorArrayFromColorName_v240709";
    cA = newArray(255, 255, 255); /* defaults to white */
    if (colorName == "white") cA = newArray(255, 255, 255);
    else if (colorName == "black") cA = newArray(0, 0, 0);
    else if (colorName == "off-white") cA = newArray(245, 245, 245);
    else if (colorName == "off-black") cA = newArray(10, 10, 10);
    else if (colorName == "lightGray") cA = newArray(192, 192, 192);
    else if (colorName == "gray") cA = newArray(127, 127, 127);
    else if (colorName == "darkGray") cA = newArray(64, 64, 64);
    else if (colorName == "red") cA = newArray(255, 0, 0);
    else if (colorName == "green") cA = newArray(0, 255, 0); /* #00FF00 AKA Lime green */
    else if (colorName == "blue") cA = newArray(0, 0, 255);
    else if (colorName == "cyan") cA = newArray(0, 255, 255);
    else if (colorName == "yellow") cA = newArray(255, 255, 0);
    else if (colorName == "magenta") cA = newArray(255, 0, 255); /* #FF00FF */
    else if (colorName == "pink") cA = newArray(255, 192, 203);
    else if (colorName == "violet") cA = newArray(127, 0, 255);
    else if (colorName == "orange") cA = newArray(255, 165, 0);
    /* Excel Modern  + */
    else if (colorName == "aqua_modern") cA = newArray(75, 172, 198); /* #4bacc6 AKA "Viking" aqua */
    else if (colorName == "blue_accent_modern") cA = newArray(79, 129, 189); /* #4f81bd */
    else if (colorName == "blue_dark_modern") cA = newArray(31, 73, 125); /* #1F497D */
    else if (colorName == "blue_honolulu") cA = newArray(0, 118, 182); /* Honolulu Blue #006db0 */
    else if (colorName == "blue_modern") cA = newArray(58, 93, 174); /* #3a5dae */
    else if (colorName == "gray_modern") cA = newArray(83, 86, 90); /* bright gray #53565A */
    else if (colorName == "green_dark_modern") cA = newArray(121, 133, 65); /* Wasabi #798541 */
    else if (colorName == "green_modern") cA = newArray(155, 187, 89); /* #9bbb59 AKA "Chelsea Cucumber" */
    else if (colorName == "green_modern_accent") cA = newArray(214, 228, 187); /* #D6E4BB AKA "Gin" */
    else if (colorName == "green_spring_accent") cA = newArray(0, 255, 102); /* #00FF66 AKA "Spring Green" */
    else if (colorName == "orange_modern") cA = newArray(247, 150, 70); /* #f79646 tan hide, light orange */
    else if (colorName == "pink_modern") cA = newArray(255, 105, 180); /* hot pink #ff69b4 */
    else if (colorName == "purple_modern") cA = newArray(128, 100, 162); /* blue-magenta, purple paradise #8064A2 */
    else if (colorName == "red_modern") cA = newArray(227, 24, 55);
    else if (colorName == "tan_modern") cA = newArray(238, 236, 225);
    else if (colorName == "violet_modern") cA = newArray(76, 65, 132);
    else if (colorName == "yellow_modern") cA = newArray(247, 238, 69);
    /* FSU */
    else if (colorName == "garnet") cA = newArray(120, 47, 64); /* #782F40 */
    else if (colorName == "gold") cA = newArray(206, 184, 136); /* #CEB888 */
    else if (colorName == "gulf_sands") cA = newArray(223, 209, 167); /* #DFD1A7 */
    else if (colorName == "stadium_night") cA = newArray(16, 24, 32); /* #101820 */
    else if (colorName == "westcott_water") cA = newArray(92, 184, 178); /* #5CB8B2 */
    else if (colorName == "vault_garnet") cA = newArray(166, 25, 46); /* #A6192E */
    else if (colorName == "legacy_blue") cA = newArray(66, 85, 99); /* #425563 */
    else if (colorName == "plaza_brick") cA = newArray(66, 85, 99); /* #572932 */
    else if (colorName == "vault_gold") cA = newArray(255, 199, 44); /* #FFC72C */
    /* Materials */
    else if (colorName == "bronze") cA = newArray(205, 127, 50); /* #CD7F32 */
    else if (colorName == "antique_bronze") cA = newArray(102, 93, 30); /* #665D1E */
    else if (colorName == "brass") cA = newArray(181, 166, 66); /* #B5A642 */
    else if (colorName == "brick") cA = newArray(192, 80, 77);
    else if (colorName == "dull_brass") cA = newArray(142, 124, 80); /* #8E7C50 */
    else if (colorName == "burnished_gold") cA = newArray(133, 109, 77); /* #856D4D */
    else if (colorName == "chrome") cA = newArray(229, 228, 226); /* #E5E4E2 */
    else if (colorName == "copper") cA = newArray(184, 115, 51); /* #B87333 */
    else if (colorName == "aged_copper") cA = newArray(110, 58, 7); /* #6E3A07 */
    else if (colorName == "dusky_copper") cA = newArray(110, 59, 59); /* #6E3B3B */
    else if (colorName == "light_copper") cA = newArray(218, 138, 103); /* #DA8A67 */
    else if (colorName == "slate_gray") cA = newArray(112, 128, 144); /* #708090 */
    else if (colorName == "titanium") cA = newArray(135, 134, 129); /* #878681 */
    /* Fluorescent Colors https://www.w3schools.com/colors/colors_crayola.asp   */
    else if (colorName == "radical_red") cA = newArray(255, 53, 94); /* #FF355E */
    else if (colorName == "jazzberry_jam") cA = newArray(165, 11, 94);
    else if (colorName == "wild_watermelon") cA = newArray(253, 91, 120); /* #FD5B78 */
    else if (colorName == "shocking_pink") cA = newArray(255, 110, 255); /* #FF6EFF Ultra Pink */
    else if (colorName == "razzle_dazzle_rose") cA = newArray(238, 52, 210); /* #EE34D2 */
    else if (colorName == "hot_magenta") cA = newArray(255, 0, 204); /* #FF00CC AKA Purple Pizzazz */
    else if (colorName == "outrageous_orange") cA = newArray(255, 96, 55); /* #FF6037 */
    else if (colorName == "supernova_orange") cA = newArray(255, 191, 63); /* FFBF3F Supernova Neon Orange*/
    else if (colorName == "sunglow") cA = newArray(255, 204, 51); /* #FFCC33 */
    else if (colorName == "neon_carrot") cA = newArray(255, 153, 51); /* #FF9933 */
    else if (colorName == "atomic_tangerine") cA = newArray(255, 153, 102); /* #FF9966 */
    else if (colorName == "laser_lemon") cA = newArray(255, 255, 102); /* #FFFF66 "Unmellow Yellow" */
    else if (colorName == "electric_lime") cA = newArray(204, 255, 0); /* #CCFF00 */
    else if (colorName == "screamin'_green") cA = newArray(102, 255, 102); /* #66FF66 */
    else if (colorName == "magic_mint") cA = newArray(170, 240, 209); /* #AAF0D1 */
    else if (colorName == "blizzard_blue") cA = newArray(80, 191, 230); /* #50BFE6 Malibu */
    else if (colorName == "dodger_blue") cA = newArray(9, 159, 255); /* #099FFF Dodger Neon Blue */
    else IJ.log(colorName + " not found in " + functionL + ": Color defaulted to white");
    return cA;
}

function setColorFromColorName(colorName) {
    colorArray = getColorArrayFromColorName(colorName);
    setColor(colorArray[0], colorArray[1], colorArray[2]);
}

function restoreExit(message) {
    /* v220316
		NOTE: REQUIRES previous run of saveSettings	*/
    restoreSettings(); /* Restore previous settings before exiting */
    setBatchMode("exit & display"); /* Probably not necessary if exiting gracefully but otherwise harmless */
    call("java.lang.System.gc");
    if (message != "") exit(message);
    else exit;
}
function stripKnownExtensionFromString(string) {
	/*	Note: Do not use on path as it may change the directory names
	v210924: Tries to make sure string stays as string.	v211014: Adds some additional cleanup.	v211025: fixes multiple 'known's issue.	v211101: Added ".Ext_" removal.
	v211104: Restricts cleanup to end of string to reduce risk of corrupting path.	v211112: Tries to fix trapped extension before channel listing. Adds xlsx extension.
	v220615: Tries to fix the fix for the trapped extensions ...	v230504: Protects directory path if included in string. Only removes doubled spaces and lines.
	v230505: Unwanted dupes replaced by unusefulCombos.	v230607: Quick fix for infinite loop on one of while statements.
	v230614: Added AVI.	v230905: Better fix for infinite loop. v230914: Added BMP and "_transp" and rearranged
	*/
	fS = File.separator;
	string = "" + string;
	protectedPathEnd = lastIndexOf(string, fS) + 1;
	if (protectedPathEnd > 0) {
		protectedPath = substring(string, 0, protectedPathEnd);
		string = substring(string, protectedPathEnd);
	}
	unusefulCombos = newArray("-", "_", " ");
	for (i = 0; i < lengthOf(unusefulCombos); i++) {
		for (j = 0; j < lengthOf(unusefulCombos); j++) {
			combo = unusefulCombos[i] + unusefulCombos[j];
			while (indexOf(string, combo) >= 0) string = replace(string, combo, unusefulCombos[i]);
		}
	}
	if (lastIndexOf(string, ".") > 0 || lastIndexOf(string, "_lzw") > 0) {
		knownExts = newArray(".avi", ".csv", ".bmp", ".dsx", ".gif", ".jpg", ".jpeg", ".jp2", ".png", ".tif", ".txt", ".xlsx");
		knownExts = Array.concat(knownExts, knownExts, "_transp", "_lzw");
		kEL = knownExts.length;
		for (i = 0; i < kEL / 2; i++) knownExts[i] = toUpperCase(knownExts[i]);
		chanLabels = newArray(" \(red\)", " \(green\)", " \(blue\)", "\(red\)", "\(green\)", "\(blue\)");
		for (i = 0, k = 0; i < kEL; i++) {
			for (j = 0; j < chanLabels.length; j++) {
				/* Looking for channel-label-trapped extensions */
				iChanLabels = lastIndexOf(string, chanLabels[j]) - 1;
				if (iChanLabels > 0) {
					preChan = substring(string, 0, iChanLabels);
					postChan = substring(string, iChanLabels);
					while (indexOf(preChan, knownExts[i]) > 0) {
						preChan = replace(preChan, knownExts[i], "");
						string = preChan + postChan;
					}
				}
			}
			while (endsWith(string, knownExts[i])) string = "" + substring(string, 0, lastIndexOf(string, knownExts[i]));
		}
	}
	unwantedSuffixes = newArray(" ", "_", "-");
	for (i = 0; i < unwantedSuffixes.length; i++) {
		while (endsWith(string, unwantedSuffixes[i])) string = substring(string, 0, string.length - lengthOf(unwantedSuffixes[i])); /* cleanup previous suffix */
	}
	if (protectedPathEnd > 0) {
		if (!endsWith(protectedPath, fS)) protectedPath += fS;
		string = protectedPath + string;
	}
	return string;
}
function tableSetColumnValue(columnName, value) {
    /* Original version v190905 to overcome Table macro limitation - PJL
    	v190906 Add table update
    	v200730 If value cannot be converted to number it is entered as a string
    	NOTE: REQUIRES ASC restoreExit function which requires previous run of saveSettings
    */
    if (Table.size > 0) {
        tempArray = newArray(Table.size);
        number = parseFloat(value);
        if (isNaN(number))
            for (i = 0; i < Table.size; i++) Table.set(columnName, i, value);
        else {
            Array.fill(tempArray, number);
            Table.setColumn(columnName, tempArray);
        }
        Table.update;
    } else restoreExit("No Table for array fill");
}