local function splitString(inputstr, sep)
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

lib.callback.register('appointments:getphone', function(playerId, phoneNumber)
  local phoneNumber = exports['qs-base']:GetPlayerPhone(playerId)
  return phoneNumber
end)

lib.callback.register('appointments:getidentifier', function(playerId)
  local xPlayer = ESX.GetPlayerFromId(playerId)
  if xPlayer then
    local identifier = xPlayer.identifier
    return identifier
  end
end)

local function checkForExistingAppointments(playerId, job)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if xPlayer then
        local identifier = xPlayer.identifier
        local count
        if job then
            count = exports.oxmysql:scalarSync('SELECT COUNT(*) FROM appointments WHERE player_license = ? AND job = ?', {identifier, job})
        else
            count = exports.oxmysql:scalarSync('SELECT COUNT(*) FROM appointments WHERE player_license = ?', {identifier})
        end
        local hasAppointment = count > 0
        return hasAppointment
    end
end

lib.callback.register('appointments:checkExistingAppointment', function(playerId, job)
    return checkForExistingAppointments(playerId, job)
end)

local function getAppointments(job)
    local fetchedAppointments = exports.oxmysql:executeSync('SELECT * FROM appointments WHERE job = ?', {job})
    return fetchedAppointments
end

local appointmentTypeLabels = {
    permis_arme = 'Demande de permis port d\'arme',
    convocation = 'Convocation officielle',
    plainte = 'Porter plainte',
    recrutement = 'Demande de recrutement',
    achat = 'Achat de logement',
    visite = 'Visite de maisons',
    soins = 'Demande de soins médicaux',
    custom =  'Customisation de véhicule'
}

local function formatDate(milliseconds)
    local dateInSeconds = milliseconds / 1000 -- Convert milliseconds to seconds
    local formattedDate = os.date('%d/%m/%Y', dateInSeconds) -- Format date as DD/MM/YYYY
    return formattedDate
end

lib.callback.register('appointments:getAllAppointments', function(playerId)
    local playerIdentifier = ESX.GetPlayerFromId(playerId).identifier
    if playerIdentifier then
        local fetchedAppointments = exports.oxmysql:executeSync('SELECT * FROM appointments WHERE player_license = ?', {playerIdentifier})
        for _, appointment in ipairs(fetchedAppointments) do
            appointment.date = formatDate(appointment.date)
            appointment.appointment_type_label = appointmentTypeLabels[appointment.appointment_type]
        end
        return fetchedAppointments
    end
end)

lib.callback.register('appointments:getAppointments', function(playerId, job)
    local appointments = getAppointments(job)
    for _, appointment in ipairs(appointments) do
        appointment.date = formatDate(appointment.date)
        appointment.appointment_type_label = appointmentTypeLabels[appointment.appointment_type]
    end
    return appointments
end)


RegisterNetEvent('appointments:storeAppointment')
AddEventHandler('appointments:storeAppointment', function(appointmentData)
  local dateParts = splitString(appointmentData.date, '/')
  local formattedDate = dateParts[3].."-"..dateParts[2].."-"..dateParts[1]
  local formattedTime = os.date("%H:%M:%S", appointmentData.time / 1000)
  exports.oxmysql:insert('INSERT INTO appointments (player_license, date, time, appointment_type, message, phone_number, job) VALUES (?, ?, ?, ?, ?, ?, ?)', {
      appointmentData.identifier,
      formattedDate,
      formattedTime,
      appointmentData.type,
      appointmentData.message,
      appointmentData.phoneNumber,
      appointmentData.job
  }, function(insertId)
      print("Appointment data inserted with ID: " .. insertId)
  end)
end)

RegisterNetEvent('appointments:confirmDeleteAppointment')
AddEventHandler('appointments:confirmDeleteAppointment', function(appointmentId)
    local src = source
    local affectedRows = exports.oxmysql:executeSync('DELETE FROM appointments WHERE id = ?', {appointmentId})
    if affectedRows.affectedRows > 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Rendez-vous',
            description = 'Rendez-vous id ' .. appointmentId .. ' supprimé avec succès.',
            type = 'success',
            position = 'top',
            style = {backgroundColor = '#141517', color = '#d6d6d6'}
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Rendez-vous',
            description = 'Échec de la suppression du rendez-vous id ' .. appointmentId .. '.',
            type = 'error',
            position = 'top',
            style = {backgroundColor = '#141517', color = '#d6d6d6'}
        })
    end
end)


RegisterNetEvent('appointments:updateAppointment')
AddEventHandler('appointments:updateAppointment', function(updatedAppointment)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local id = updatedAppointment.id
        local date = updatedAppointment.date
        local time = updatedAppointment.time
        local dateParts = splitString(date, '/')
        local formattedDate = string.format('%s-%s-%s', dateParts[3], dateParts[2], dateParts[1])
        local formattedTime = os.date("%H:%M:%S", updatedAppointment.time / 1000)
        exports.oxmysql:execute('UPDATE appointments SET date = ?, time = ? WHERE id = ?', {formattedDate, formattedTime, id}, function(rowsChanged)
            if rowsChanged.changedRows > 0 then
                TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                    title = 'Rendez-vous mis à jour',
                    description = 'La date et l\'heure du rendez-vous ont été mises à jour avec succès.',
                    type = 'success',
                    position = 'top',
                    style = {backgroundColor = '#141517', color = '#d6d6d6'}
                })
            else
                TriggerClientEvent('ox_lib:notify', xPlayer.source, {
                    title = 'Erreur de mise à jour',
                    description = 'Une erreur est survenue lors de la mise à jour du rendez-vous.',
                    type = 'error',
                    position = 'top',
                    style = {backgroundColor = '#141517', color = '#d6d6d6'}
                })
            end
        end)
    end
end)
