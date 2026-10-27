local M = {}

local logTag = "FrameGenNG"
local shutdownSignalPath = "/temp/frame_generation_shutdown.signal"

local function clearStaleSignal()
  if FS:fileExists(shutdownSignalPath) then
    FS:removeFile(shutdownSignalPath)
  end
end

function M.onExtensionLoaded()
  clearStaleSignal()
  log("I", logTag, "Lifecycle bridge loaded")
end

function M.onPreExit()
  local written = writeFile(shutdownSignalPath, tostring(os.time()) .. "\n")
  if written then
    log("I", logTag, "Frame-generation shutdown signal written")
  else
    log("E", logTag, "Unable to write the frame-generation shutdown signal")
  end
end

return M

