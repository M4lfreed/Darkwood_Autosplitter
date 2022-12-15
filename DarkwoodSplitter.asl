state("Darkwood") {}

// Runs when the ASL is hooked up
startup {
	// List of settings 
	settings.Add("Split on every 1st location enter", true);
	settings.Add("Split on death in 1st chapter", true);

	// Create a log file for the autosplitter
	vars.logFilePath = Directory.GetCurrentDirectory() + "\\autosplitter_darkwood.log";
	// Log output
	vars.log = (Action<string>)((string logLine) => {
		print(logLine);
		string time = System.DateTime.Now.ToString("dd/MM/yy hh:mm:ss:fff");
		System.IO.File.AppendAllText(vars.logFilePath, time + ": " + logLine + "\r\n");
	});
	// Finish loading. If there is no log file - create one.
	
	if (File.Exists(vars.logFilePath)) {
		try { // Wipe the asl log file to clear out messages from last time
			FileStream fs = new FileStream(vars.logFilePath, FileMode.Open, FileAccess.Write, FileShare.ReadWrite);
			fs.SetLength(0);
			fs.Close();
			vars.log("ASL log file cleared");
		} catch {}
	}
	
	try {
		vars.log("Autosplitter loaded");
	} catch (System.IO.FileNotFoundException e) {
		System.IO.File.Create(vars.logFilePath);
		vars.log("Autosplitter loaded, log file created");
	}

}

// Runs when the "Darkwood" process is found
init {
	// Find the game log file in the darkwood directory and start a reader
	var page = modules.First();
	vars.loading = false;
	var gameDir = Path.GetDirectoryName(page.FileName);
	vars.log("Game directory: '" + gameDir + "'");
	var logPath = gameDir + "\\Darkwood_Data\\output_log.txt";
	vars.log("Computed log path: '" + logPath + "'");
	
	
	//System.Threading.Thread.Sleep(10); // Wait a bit before checking for the log file, because the game process creates one.
	if (File.Exists(logPath)) {
		try { // Wipe the game log file to clear out messages from last time
			FileStream fs = new FileStream(logPath, FileMode.Open, FileAccess.Write, FileShare.ReadWrite);
			fs.SetLength(0);
			fs.Close();
			vars.log("Game log file cleared");
		} catch {} // May fail if file doesn't exist.
		vars.reader = new StreamReader(new FileStream(logPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite));
		vars.log("Log file found and in use, ready to work.");
	} else {
		vars.log("No log file found at computed log path, automatic start, stop, and splits will not work. Loading should still work if the timer is started manually.");
		// Set defaults for the rest of the script. The start/split/reset blocks will not run, but the isLoading block will.
		vars.reader = null;
		vars.line = null;
	}
	vars.episode = "chapter 1"; // Note: Change this line if prologue will be used in speedruns. Var to track in which part of the run we're in

	vars.log("Init finished.");
}


exit {
	timer.IsGameTimePaused = true;
	vars.reader = null; // Free the lock on the game logfile
}

update {
	// vars.log("tick"); // testing
	// If the loader found the log file
	while (vars.reader != null) {
		vars.line = vars.reader.ReadLine();
		
		if (vars.line == null || vars.line.Length <= 1) return false; // skip a tick if the reader line is empty
		else if (vars.line.StartsWith("(Filename")) continue; // ignore some of the useless data from the game log
		else {
			//vars.log("ASL NOW READS LINE: " + vars.line); // this line logs everything rather useful from the game log file. This line is used for debug
			return true;
		}
		break;
	}
}

start { // This block works after update - if it did not explicitly return false this tick
	//vars.log("checking if I have to start");
	if (vars.line == null) return false; // If the log file line is empty, don't run this block.

	if (vars.line == "start chapter 1"){
		vars.episode = "chapter 1";
		vars.log("Starting a new run in Chapter 1");
		vars.loading = false;
		return true;
	}
}

isLoading { // Returning True pauses the timer for that tick.
	// vars.log("Checking if isLoading");
	if (vars.line == "save empty chapter save") { // Pause timer while chapter 2 is generating
		vars.loading = true;
		vars.log("Setting loading to true");
	} else if (vars.line == "start chapter 2") { // Unpause when chapter 2 starts
		vars.loading = false;
		vars.log("Setting loading to false");
	}
	return vars.loading;
}

reset { // this block works after isloading and gametime - if the timer is running (not paused + has started)
	if (vars.line == null) return false; // If the log file line is empty, don't run this block.
	//vars.log("Checking if have to reset");
	if (vars.line == "RETURN TO MAIN MENU."){ // Reset if player goes to main menu
		vars.log("Resetting the run");
		vars.episode = "chapter 1";
		return true;
	}
}

split { // This block works last
	//vars.log("Checking if I have to split");
	if (vars.line == null) return false; // If the log file line is empty, don't run this block.
		
	if (vars.line == "start chapter 2") {
		vars.episode = "chapter 2";
		vars.log("SPLIT: chapter 2 start");
		return true; // Split on chapter 2 because it has no enter location trigger
	}
	if (vars.line == "start epilogue") {
		vars.episode = "epilogue";
		if (!(settings["Split on every location enter"])) // Start Epilogue has an enter loc trigger, so we don't want to split twice
		{
			vars.log("SPLIT: epilogue start");
			return true;
		}
	}
	
	if (vars.line == "Can not play a disabled audio source" && vars.episode == "bedroom"){ // This line works because of a Darkwood dev mistake! This may be ruined when game updates 
		vars.log("SPLIT: Lie down on bed_epilogue triggered");
		return true; // Split on lie down on bed_epilogue
	}
	//if (vars.line.StartsWith("Start outcomes")) return true; // remove comment if "Can not play a disabled audio source"  has been fixed by the game author.
	
	if (vars.line.StartsWith("Start preparing location epilog_part1c_room_dream")) {
		vars.episode = "bedroom"; // set episode to bedroom so the "can not play a disabled audio source" works ONLY in the last Bedroom. Remove if it gets fixed
		vars.log("Setting the episode to bedroom");
	}
	
	if (settings["Split on every location enter"]) {
		if (vars.line.StartsWith("Start preparing location")) {
			vars.log("SPLIT: entering a new location");
			return true;
		} 
	}
	
	if (settings["Split on death in 1st chapter"]) { 
		//vars.log("Split on death in 1st chapter is active");
		if (vars.line.StartsWith("Player death") && vars.episode == "chapter 1") {
			vars.log("SPLIT: died in the 1st chapter");
			return true;
		}
	}
}







