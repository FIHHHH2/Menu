-- MCP Connection Script
local function connectToMCP()
    -- Check for existing MCP clients
    local clients = tool.roblox-mcp_list-clients()
    if #clients == 0 then
        tool.question({
            questions = {
                {
                    question = "No connected MCP clients found. Please ensure Roblox Studio is running with MCP enabled. Would you like to retry?";
                    header = "MCP Connection";
                    options = {
                        { label = "Retry", description = "Attempt to connect again" },
                        { label = "Cancel", description = "Abort connection attempt" }
                    }
                }
            }
        })
        return
    end

    -- Single client: auto-connect
    if #clients == 1 then
        tool.roblox-mcp_set-active-client({ clientId = clients[1].clientId })
        tool.question({
            questions = {
                {
                    question = "Successfully connected to MCP client!";
                    header = "Connection Established";
                    options = {
                        { label = "OK", description = "Continue" }
                    }
                }
            }
        })
        return
    end

    -- Multiple clients: let user choose
    local options = {}
    for _, client in ipairs(clients) do
        table.insert(options, {
            label = client.clientId,
            description = "Client ID: " .. client.clientId
        })
    end

    tool.question({
        questions = {
            {
                question = "Multiple MCP clients detected. Select one to connect:";
                header = "Choose Client";
                options = options
            }
        }
    }):connect(function(selected)
        if selected and selected[1] then
            tool.roblox-mcp_set-active-client({ clientId = selected[1].label })
            tool.question({
                questions = {
                    {
                        question = "Connected to client: " .. selected[1].label;
                        header = "Success";
                        options = {
                            { label = "OK", description = "Continue" }
                        }
                    }
                }
            })
        end
    end)
end

connectToMCP()