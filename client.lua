RegisterNetEvent('opod-reports:OpenReportMenu', function(identifier)
    local isAdmin = lib.callback.await('opod-reports:CheckIfAdmin', false)
    local hasAce = lib.callback.await('opod-reports:CheckForAce', false)
    print('isAdmin', isAdmin)
    print('hasAce', hasAce)
    SendNUIMessage({
        action = 'setVisible',
        data = true
    })

    SendNUIMessage({
        action = 'setIdentifier',
        data = identifier
    })

    SendNUIMessage({
        action = 'setAdmin',
        data = isAdmin
    })
    
    SendNUIMessage({
        action = 'setAce',
        data = hasAce
    })
    
    SetNuiFocus(true, true)
end)

RegisterNetEvent('opod-reports:ForceUpdate', function(activeReports)
    SendNUIMessage({
        action = 'forceUpdate',
        data = activeReports
    })
end)

RegisterNUICallback('updateStatus', function(data, cb)
    TriggerServerEvent('opod-reports:UpdateReportStatus', data.report, data.status)

    cb('ok')
end)
RegisterNUICallback('submitNewReport', function(data, cb)
    TriggerServerEvent('opod-reports:SubmitNewReport', data.title, data.description, data.type)
    cb('ok')
end)
RegisterNUICallback('sendChatMessage', function(data, cb)
    TriggerServerEvent('opod-reports:SendReportMessage', data.report, data.message)
    cb('ok')
end)

RegisterNUICallback('reportAction', function(data)
    TriggerServerEvent('opod-reports:ReportAction', data.action, tonumber(data.target), data.report, data.payload)
end)

RegisterNUICallback('handleTeleport', function()
    TriggerServerEvent('opod-reports:TeleportToAdminZone')
end)

RegisterNUICallback('closeMenu', function(data)
    SendNUIMessage({
        action = 'setVisible',
        data = false
    })
    
    SetNuiFocus(false, false)

    TriggerServerEvent('opod-reports:RegisterCloseMenu')
end)

RegisterNUICallback('getReportData', function(data, cb)
    local report_data = lib.callback.await('opod-reports:GetAdditionalReportData', false, data.report)
    cb(report_data)
end)

RegisterNUICallback('getLeaderboards', function(data, cb)
    local permanent = data.perm 
    local leaderboard = lib.callback.await('opod-reports:GetStaffLeaderboard', false, permanent)

    local tbl = {}

    for k, v in pairs(leaderboard) do
        table.insert(tbl, { count = v.count, name = v.name, identifier = k })
    end

    cb(tbl)
end)

RegisterNUICallback('getReports', function(data, cb)
    local reports = lib.callback.await('opod-reports:GetActiveReports', false)
    
    cb(reports)
end)

CreateThread(function()
    local activeTextUI = nil
    local insideAdminZone = false
    local point = lib.points.new({
        coords = Config.AdminZone.coords,
        zCoord = Config.AdminZone.coords.z - 50,
        distance = Config.AdminZone.radius,
        markerSize = Config.AdminZone.radius * 2
    })
    
    function point:onEnter()
        insideAdminZone = true
        activeTextUI = "adminzone"
        lib.showTextUI("You are inside the Adminzone", {
            position = "top-center",
            icon = "fa-solid fa-shield-halved", -- Updated to a valid FontAwesome icon
            style = {
                backgroundColor = "rgba(0, 0, 0, 0.75)",
                color = "red",
                padding = "10px",
                borderRadius = "5px"
            }
        })
    end
     
    function point:onExit()
        if activeTextUI == "adminzone" then
            lib.hideTextUI()
            activeTextUI = nil
            insideAdminZone = false
        end
    end

    -- Optimized TextUI refresh loop - only runs when inside admin zone
    CreateThread(function()
        while true do
            Wait(25) -- Check every 5 seconds
            if insideAdminZone then
                lib.showTextUI("You are inside the Adminzone", {
                    position = "top-center",
                    icon = "fa-solid fa-shield-halved", -- Ensure valid icon usage
                    style = {
                        backgroundColor = "rgba(0, 0, 0, 0.75)",
                        color = "red",
                        padding = "10px",
                        borderRadius = "5px"
                    }
                })
                activeTextUI = "adminzone"
            end
        end
    end)
     
end)
