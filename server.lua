local activeReports = {}
local reportCounter = 0
local staffStats = {}

-- Report types available
local reportTypes = {
    "Bug Report",
    "Player Report",
    "Question",
    "Suggestion",
    "Other"
}

-- Helper function to check if player is admin
local function IsPlayerAdmin(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    local group = xPlayer.getGroup()
    return Config.AdminGroups[group] or false
end

-- Helper function to check for ACE permissions
local function HasAcePermission(source)
    return IsPlayerAceAllowed(source, "opod.reports.admin")
end

-- Helper function to get player identifier
local function GetPlayerIdentifier(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end
    return xPlayer.identifier
end

-- Helper function to get player name
local function GetPlayerName(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return "Unknown" end
    return xPlayer.getName()
end

-- Helper function to get Discord identifier
local function GetDiscordIdentifier(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in pairs(identifiers) do
        if string.match(id, "discord:") then
            return id
        end
    end
    return "N/A"
end

-- Helper function to get Steam identifier
local function GetSteamIdentifier(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in pairs(identifiers) do
        if string.match(id, "steam:") then
            return id
        end
    end
    return "N/A"
end

-- Helper function to send notification
local function SendNotification(source, title, message, type)
    TriggerClientEvent('esx:showNotification', source, message)
    -- Alternative if you have ox_lib notifications:
    -- TriggerClientEvent('ox_lib:notify', source, {
    --     title = title,
    --     description = message,
    --     type = type
    -- })
end

-- Helper function to format report for NUI
local function FormatReportForNUI(reportId, report)
    return {
        id = reportId,
        type = report.type or "report",
        status = report.status or "waiting",
        time = report.created_at or os.time(),
        report = {
            name = report.reporter_name or "Unknown",
            title = report.title or "No Title",
            description = report.description or "No Description",
            admin = report.assigned_name or nil,
            identifiers = {
                license = report.reporter or "N/A",
                discord = report.discord or "N/A",
                steam = report.steam or "N/A",
                source = report.reporter_source or nil
            },
            profile = "https://cdn.cloudflare.steamstatic.com/steamcommunity/public/images/items/1768020/fc52e0d76e08ca662d3f5cae9de01fc6ecce8e1e.gif"
        },
        chat = report.messages or {}
    }
end

-- Load staff stats from database
CreateThread(function()
    Wait(1000)
    MySQL.query('SELECT * FROM opod_staff_stats', {}, function(results)
        if results then
            for _, row in ipairs(results) do
                staffStats[row.identifier] = {
                    count = row.report_count or 0,
                    permanent_count = row.permanent_count or 0,
                    name = row.name or "Unknown"
                }
            end
        end
    end)
end)

-- Create database tables if they don't exist
CreateThread(function()
    Wait(500)
    
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS opod_reports (
            id INT AUTO_INCREMENT PRIMARY KEY,
            report_id INT NOT NULL,
            reporter_identifier VARCHAR(60) NOT NULL,
            reporter_name VARCHAR(100) NOT NULL,
            title VARCHAR(255) NOT NULL,
            description TEXT NOT NULL,
            type VARCHAR(50) NOT NULL,
            status VARCHAR(50) DEFAULT 'waiting',
            assigned_to VARCHAR(60) DEFAULT NULL,
            assigned_name VARCHAR(100) DEFAULT NULL,
            discord VARCHAR(100) DEFAULT NULL,
            steam VARCHAR(100) DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_report_id (report_id),
            INDEX idx_status (status)
        )
    ]], {})

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS opod_report_messages (
            id INT AUTO_INCREMENT PRIMARY KEY,
            report_id INT NOT NULL,
            sender_identifier VARCHAR(60) NOT NULL,
            sender_name VARCHAR(100) NOT NULL,
            message TEXT NOT NULL,
            timestamp INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_report_id (report_id)
        )
    ]], {})

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS opod_staff_stats (
            identifier VARCHAR(60) PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            report_count INT DEFAULT 0,
            permanent_count INT DEFAULT 0,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]], {})
end)

-- Callbacks
lib.callback.register('opod-reports:CheckIfAdmin', function(source)
    return IsPlayerAdmin(source)
end)

lib.callback.register('opod-reports:CheckForAce', function(source)
    return HasAcePermission(source)
end)

lib.callback.register('opod-reports:GetActiveReports', function(source)
    local reports = {}
    for reportId, report in pairs(activeReports) do
        table.insert(reports, FormatReportForNUI(reportId, report))
    end
    return reports
end)

lib.callback.register('opod-reports:GetAdditionalReportData', function(source, reportId)
    local report = activeReports[reportId]
    if not report then return {source = nil} end
    
    -- Check if reporter is still online
    local reporterSource = nil
    local xPlayers = ESX.GetExtendedPlayers()
    for _, xPlayer in pairs(xPlayers) do
        if xPlayer.identifier == report.reporter then
            reporterSource = xPlayer.source
            break
        end
    end
    
    return {
        source = reporterSource
    }
end)

lib.callback.register('opod-reports:GetStaffLeaderboard', function(source, permanent)
    local leaderboard = {}
    
    for identifier, data in pairs(staffStats) do
        leaderboard[identifier] = {
            count = permanent and data.permanent_count or data.count,
            name = data.name
        }
    end
    
    return leaderboard
end)

lib.callback.register('opod-reports:GetReportTypes', function(source)
    return reportTypes
end)

-- Helper function to notify admins
local function NotifyAdmins(reports, newReport)
    local xPlayers = ESX.GetExtendedPlayers()
    for _, xPlayer in pairs(xPlayers) do
        if IsPlayerAdmin(xPlayer.source) or HasAcePermission(xPlayer.source) then
            TriggerClientEvent('opod-reports:ForceUpdate', xPlayer.source, reports)
            
            -- Send notification for new reports
            if newReport then
                SendNotification(xPlayer.source, 'New Report', 'A new report has been submitted!', 'info')
            end
        end
    end
end

-- Helper function to get formatted reports for NUI
local function GetFormattedReports()
    local formattedReports = {}
    for reportId, report in pairs(activeReports) do
        formattedReports[reportId] = FormatReportForNUI(reportId, report)
    end
    return formattedReports
end

-- Events
RegisterNetEvent('opod-reports:SubmitNewReport', function(title, description, reportType)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    local name = GetPlayerName(src)
    
    if not identifier then return end
    
    reportCounter = reportCounter + 1
    
    local report = {
        reporter = identifier,
        reporter_name = name,
        reporter_source = src,
        title = title,
        description = description,
        type = reportType,
        status = 'waiting',
        assigned_to = nil,
        assigned_name = nil,
        created_at = os.time(),
        messages = {},
        discord = GetDiscordIdentifier(src),
        steam = GetSteamIdentifier(src)
    }
    
    activeReports[reportCounter] = report
    
    -- Save to database
    MySQL.insert('INSERT INTO opod_reports (report_id, reporter_identifier, reporter_name, title, description, type, status, discord, steam) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        reportCounter,
        identifier,
        name,
        title,
        description,
        reportType,
        'waiting',
        report.discord,
        report.steam
    })
    
    -- Notify player
    SendNotification(src, 'Report Submitted', 'Your report has been submitted successfully!', 'success')
    
    -- Notify all admins with notification
    local formattedReports = GetFormattedReports()
    NotifyAdmins(formattedReports, true)
    TriggerClientEvent('opod-reports:ForceUpdate', src, formattedReports)
end)

RegisterNetEvent('opod-reports:UpdateReportStatus', function(reportId, status)
    local src = source
    
    if not IsPlayerAdmin(src) and not HasAcePermission(src) then return end
    
    local report = activeReports[reportId]
    if not report then return end
    
    report.status = status
    
    -- Update database
    MySQL.update('UPDATE opod_reports SET status = ? WHERE report_id = ?', {status, reportId})
    
    -- If closing report, update staff stats
    if status == 'completed' and report.assigned_to then
        if not staffStats[report.assigned_to] then
            staffStats[report.assigned_to] = {
                count = 0,
                permanent_count = 0,
                name = report.assigned_name or "Unknown"
            }
        end
        
        staffStats[report.assigned_to].count = staffStats[report.assigned_to].count + 1
        staffStats[report.assigned_to].permanent_count = staffStats[report.assigned_to].permanent_count + 1
        
        -- Update database
        MySQL.insert('INSERT INTO opod_staff_stats (identifier, name, report_count, permanent_count) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE report_count = report_count + 1, permanent_count = permanent_count + 1, name = ?', {
            report.assigned_to,
            report.assigned_name,
            1,
            1,
            report.assigned_name
        })
        
        -- Notify reporter if online
        if report.reporter_source and GetPlayerPing(report.reporter_source) > 0 then
            SendNotification(report.reporter_source, 'Report Completed', 'Your report has been marked as completed by ' .. report.assigned_name, 'success')
        end
    end
    
    -- Notify all relevant players
    NotifyAdmins(GetFormattedReports(), false)
    
    -- Notify reporter if online
    if report.reporter_source and GetPlayerPing(report.reporter_source) > 0 then
        TriggerClientEvent('opod-reports:ForceUpdate', report.reporter_source, GetFormattedReports())
    end
end)

RegisterNetEvent('opod-reports:SendReportMessage', function(reportId, message)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    local name = GetPlayerName(src)
    
    if not identifier then return end
    
    local report = activeReports[reportId]
    if not report then return end
    
    -- Check if player is involved in the report
    if not IsPlayerAdmin(src) and not HasAcePermission(src) and identifier ~= report.reporter then
        return
    end
    
    local messageData = {
        sender = identifier,
        senderName = name,
        message = message,
        timestamp = os.time()
    }
    
    table.insert(report.messages, messageData)
    
    -- Save to database
    MySQL.insert('INSERT INTO opod_report_messages (report_id, sender_identifier, sender_name, message, timestamp) VALUES (?, ?, ?, ?, ?)', {
        reportId,
        identifier,
        name,
        message,
        os.time()
    })
    
    -- Notify all relevant players
    NotifyAdmins(GetFormattedReports(), false)
    
    -- Notify reporter if online and it's not them sending
    if report.reporter_source and GetPlayerPing(report.reporter_source) > 0 then
        TriggerClientEvent('opod-reports:ForceUpdate', report.reporter_source, GetFormattedReports())
        
        if identifier ~= report.reporter then
            SendNotification(report.reporter_source, 'Report Message', 'An admin replied to your report!', 'info')
        end
    end
end)

RegisterNetEvent('opod-reports:ReportAction', function(action, targetId, reportId, payload)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    
    if not IsPlayerAdmin(src) and not HasAcePermission(src) then return end
    
    local report = activeReports[reportId]
    if not report then return end
    
    if action == 'claim' then
        report.assigned_to = identifier
        report.assigned_name = GetPlayerName(src)
        report.status = 'checking'
        
        MySQL.update('UPDATE opod_reports SET assigned_to = ?, assigned_name = ?, status = ? WHERE report_id = ?', {
            identifier,
            report.assigned_name,
            'checking',
            reportId
        })
        
        SendNotification(src, 'Report Claimed', 'You have claimed this report', 'success')
        
    elseif action == 'unclaim' then
        report.assigned_to = nil
        report.assigned_name = nil
        report.status = 'waiting'
        
        MySQL.update('UPDATE opod_reports SET assigned_to = NULL, assigned_name = NULL, status = ? WHERE report_id = ?', {
            'waiting',
            reportId
        })
        
        SendNotification(src, 'Report Unclaimed', 'You have unclaimed this report', 'info')
        
    elseif action == 'goto' then
        -- Auto-claim and set to checking when using goto
        if not report.assigned_to then
            report.assigned_to = identifier
            report.assigned_name = GetPlayerName(src)
            report.status = 'checking'
            
            MySQL.update('UPDATE opod_reports SET assigned_to = ?, assigned_name = ?, status = ? WHERE report_id = ?', {
                identifier,
                report.assigned_name,
                'checking',
                reportId
            })
        end
        
        local targetSource = report.reporter_source
        if targetSource and GetPlayerPing(targetSource) > 0 then
            local targetPed = GetPlayerPed(targetSource)
            local coords = GetEntityCoords(targetPed)
            local playerPed = GetPlayerPed(src)
            SetEntityCoords(playerPed, coords.x, coords.y, coords.z)
            SendNotification(src, 'Teleported', 'Teleported to reporter', 'success')
        else
            SendNotification(src, 'Error', 'Reporter is not online', 'error')
        end
        
    elseif action == 'bring' then
        -- Auto-claim and set to checking when using bring
        if not report.assigned_to then
            report.assigned_to = identifier
            report.assigned_name = GetPlayerName(src)
            report.status = 'checking'
            
            MySQL.update('UPDATE opod_reports SET assigned_to = ?, assigned_name = ?, status = ? WHERE report_id = ?', {
                identifier,
                report.assigned_name,
                'checking',
                reportId
            })
        end
        
        local targetSource = tonumber(payload) or report.reporter_source
        if targetSource and GetPlayerPing(targetSource) > 0 then
            local playerPed = GetPlayerPed(src)
            local coords = GetEntityCoords(playerPed)
            local targetPed = GetPlayerPed(targetSource)
            SetEntityCoords(targetPed, coords.x, coords.y, coords.z)
            SendNotification(src, 'Player Brought', 'Player has been brought to you', 'success')
            SendNotification(targetSource, 'Teleported', 'An admin has teleported you', 'info')
        else
            SendNotification(src, 'Error', 'Player is not online', 'error')
        end
        
    elseif action == 'revive' then
        local targetSource = report.reporter_source
        if targetSource and GetPlayerPing(targetSource) > 0 then
            -- ESX revive
            TriggerClientEvent('esx_ambulancejob:revive', targetSource)
            
            -- Alternative methods in case the above doesn't work:
            -- TriggerEvent('esx_ambulancejob:revive', targetSource)
            -- exports['esx_ambulancejob']:revivePlayer(targetSource)
            
            SendNotification(src, 'Player Revived', 'Player has been revived', 'success')
            SendNotification(targetSource, 'Revived', 'You have been revived by an admin', 'success')
        else
            SendNotification(src, 'Error', 'Reporter is not online', 'error')
        end
    end
    
    -- Notify all relevant players
    NotifyAdmins(GetFormattedReports(), false)
    
    -- Notify reporter if online
    if report.reporter_source and GetPlayerPing(report.reporter_source) > 0 then
        TriggerClientEvent('opod-reports:ForceUpdate', report.reporter_source, GetFormattedReports())
    end
end)

RegisterNetEvent('opod-reports:TeleportToAdminZone', function()
    local src = source
    
    if not IsPlayerAdmin(src) and not HasAcePermission(src) then return end
    
    local ped = GetPlayerPed(src)
    SetEntityCoords(ped, Config.AdminZone.coords.x, Config.AdminZone.coords.y, Config.AdminZone.coords.z)
    SendNotification(src, 'Teleported', 'Teleported to Admin Zone', 'success')
end)

RegisterNetEvent('opod-reports:RegisterCloseMenu', function()
    -- This can be used for tracking menu usage if needed
end)

-- Command to open report menu
RegisterCommand('report', function(source, args, rawCommand)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return end
    
    TriggerClientEvent('opod-reports:OpenReportMenu', source, identifier)
end, false)

-- Admin command to open report menu
RegisterCommand('reports', function(source, args, rawCommand)
    if not IsPlayerAdmin(source) and not HasAcePermission(source) then
        SendNotification(source, 'No Permission', 'You do not have permission to use this command', 'error')
        return
    end
    
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return end
    
    TriggerClientEvent('opod-reports:OpenReportMenu', source, identifier)
end, false)

-- Clean up old reports periodically (optional)
CreateThread(function()
    while true do
        Wait(3600000) -- Every hour
        
        local currentTime = os.time()
        local reportsToRemove = {}
        
        for reportId, report in pairs(activeReports) do
            -- Remove completed reports older than 24 hours
            if report.status == 'completed' and (currentTime - report.created_at) > 86400 then
                table.insert(reportsToRemove, reportId)
            end
        end
        
        for _, reportId in ipairs(reportsToRemove) do
            activeReports[reportId] = nil
        end
        
        if #reportsToRemove > 0 then
            NotifyAdmins(GetFormattedReports(), false)
        end
    end
end)

print('^2[OPOD Reports]^7 Server started successfully!')