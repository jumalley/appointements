local function getJobDisplayName(job)
    local jobName = {
        police = 'le LSPD',
        ambulance = 'les services EMS',
        realestate = 'l\'agence immobilière',
        mechanic = 'le mécano'
    }
    return jobName[job] or "ce service"
end

local function getJobOptions(job)
    local options = {}
    if job == "police" then
        options = {
            {value = 'permis_arme', label = 'Demande de permis port d\'arme'},
            {value = 'convocation', label = 'Convocation officielle'},
            {value = 'plainte', label = 'Porter plainte'},
            {value = 'recrutement', label = 'Demande de recrutement'}
        }
    elseif job == "ambulance" then
        options = {
            {value = 'soins', label = 'Demande de soins médicaux'},
            {value = 'convocation', label = 'Convocation officielle'},
            {value = 'permis_arme', label = 'Rendez-vous pour le permis port d\'arme'},
            {value = 'recrutement', label = 'Demande de recrutement'}
        }
        elseif job == "realestate" then
            options = {
                {value = 'visite', label = 'Visite de maisons'},
                {value = 'achat', label = 'Achat de logement'},
                {value = 'recrutement', label = 'Demande de recrutement'}
            }
            elseif job == "mechanic" then
                options = {
                    {value = 'custom', label = 'Customisation de véhicule'},
                    {value = 'recrutement', label = 'Demande de recrutement'}
                }
    else
        -- Default options
        options = {
            {value = 'default', label = 'Option par défaut'},
        }
    end
    return options
end


local function TakeAppointement(job)
  local jobDisplayName = getJobDisplayName(job)
  local playerIdentifier
  lib.callback('appointments:getidentifier', PlayerId(), function(identifier)
    playerIdentifier = identifier
    lib.callback('appointments:checkExistingAppointment', PlayerId(), function(hasAppointment)
      if not hasAppointment then
        local input = lib.inputDialog('Rendez-vous avec ' .. jobDisplayName, {
          {
            type = 'date',
            label = 'Date de rendez-vous',
            icon = {'far', 'calendar'},
            default = true,
            format = "DD/MM/YYYY",
            returnString = true,
            clearable = true
          },
          {
            type = 'time',
            label = 'Heure de rendez-vous',
            description = 'Veuillez sélectionner l\'heure du rendez-vous',
            icon = {'far', 'clock'},
            required = true,
            format = '24',
            clearable = true
          },
          {
            type = 'select',
            label = 'Type de rendez-vous',
            options = getJobOptions(job),
            placeholder = 'Sélectionnez un type de rendez-vous',
            icon = 'briefcase',
            required = true,
            clearable = true
          },
          {
            type = 'textarea',
            label = 'Laissez un message',
            description = 'Veuillez laisser un message concernant votre rendez-vous. (Optionel)',
            placeholder = 'Entrez votre message ici...',
            icon = 'comment',
            min = 4,
            max = 10,
            autosize = true
          },
          {
            type = 'checkbox',
            label = 'Laisser mon numéro de téléphone',
            description = 'Oui / Non',
            checked = false,
            required = false
          }
        })
        if not input then return end
        if input then
          if input[5] then
            lib.callback('appointments:getphone', false, function(phoneNumber)
              if phoneNumber then
                input.phoneNumber = phoneNumber
              end
              local appointmentData = {
                identifier = playerIdentifier,
                date = input[1],
                time = input[2],
                type = input[3],
                message = input[4],
                phoneNumber = input.phoneNumber,
                job = job
              }
              TriggerServerEvent('appointments:storeAppointment', appointmentData)
            end)
          else
            local appointmentData = {
              identifier = playerIdentifier,
              date = input[1],
              time = input[2],
              type = input[3],
              message = input[4],
              job = job
            }
            TriggerServerEvent('appointments:storeAppointment', appointmentData)
          end
        end
      else
        lib.notify({
          title = 'Rendez-vous',
          description = 'Vous avez déjà un rendez-vous.',
          type = 'error',
          position = 'top',
          style = {backgroundColor = '#141517', color = '#d6d6d6'}
        })
      end
    end, job)
  end)
end


local function OpenAppointment(job)
  local jobDisplayName = getJobDisplayName(job)

  lib.registerContext({
    id = 'rdvppa',
    title = 'Prise de rendez-vous',
    options = {
      {
        title = 'Prendre un rendez-vous avec ' .. jobDisplayName,
        description = 'Prendre un rendez-vous avec ' .. jobDisplayName,
        icon = 'calendar-day',
        onSelect = function()
          TakeAppointment(job)
        end,
      },
    }
  })
  lib.showContext('rdvppa')
end


local function OpenAppointmentDetails(appointment)
    lib.registerContext({
        id = 'appointments_submenu',
        title = 'Rendez-vous numéro : ' .. appointment.id,
        options = {
            {
                title = 'Type de rendez-vous',
                description = appointment.appointment_type_label,
                icon = 'circle-info',
            },
            {
                title = 'Date et heure du rendez-vous',
                description = string.format('%s - %s', appointment.date, appointment.time),
                icon = 'calendar',
                metadata = {
                    {label = 'Action', value = 'Cliquer pour modifier la date ou l\'heure'}
                },
                onSelect = function()
                    local defaultdate = appointment.date
                    local day, month, year = defaultdate:match("(%d+)/(%d+)/(%d+)")
                    local reformattedDate = month .. "/" .. day .. "/" .. year
                    local defaulttime = appointment.time
                    local hour, min = defaulttime:match("(%d+):(%d+)")
                    local timeInMillis = tonumber(hour - 1) * 3600000 + tonumber(min) * 60000

                    local input = lib.inputDialog('Rendez-vous', {
                        {
                            type = 'date',
                            label = 'Date de rendez-vous',
                            icon = {'far', 'calendar'},
                            default = reformattedDate,
                            format = "DD/MM/YYYY",
                            returnString = true,
                            clearable = true
                        },
                        {
                            type = 'time',
                            label = 'Heure de rendez-vous',
                            description = 'Veuillez sélectionner l\'heure du rendez-vous',
                            icon = {'far', 'clock'},
                            default = timeInMillis,
                            format = '24',
                            clearable = true
                        },
                    })
                    if not input then
                        return
                    end
                    local function millisecondsToHHMMSS(milliseconds)
                        local totalSeconds = math.floor(milliseconds / 1000)
                        local hours = math.floor(totalSeconds / 3600)
                        local minutes = math.floor((totalSeconds % 3600) / 60)
                        local seconds = totalSeconds % 60
                        return string.format("%02d:%02d:%02d", hours + 1, minutes, seconds)
                    end
                    local inputTimeHHMMSS = millisecondsToHHMMSS(input[2])
                    if input[1] == appointment.date and inputTimeHHMMSS == appointment.time then
                        return
                    end
                    local updatedAppointment = {
                        id = appointment.id,
                        date = input[1],
                        time = input[2],
                    }
                    TriggerServerEvent('appointments:updateAppointment', updatedAppointment)
                end,
            },
            {
                title = 'Message complet du rendez-vous',
                description = 'Pour les messages longs',
                onSelect = function()
                    lib.alertDialog({
                        header = 'Message du rendez-vous numéro : ' .. appointment.id,
                        content = appointment.message ~= "" and appointment.message or "Aucun message précisé",
                        centered = true,
                        cancel = true,
                        labels = {
                            cancel = 'Annuler',
                            confirm = 'Confirmer'
                        }
                    })
                end,
                metadata = {
                    {label = 'Action', value = 'Afficher le message complet'}
                },
                icon = 'comment'
            },
            {
                title = 'Numéro de téléphone',
                description = appointment.phone_number or "Numéro non précisé",
                icon = 'phone',
                onSelect = function()
                    if appointment.phone_number then
                    lib.notify({
                        title = 'Rendez-vous',
                        description = 'Le numéro de téléphone a été copié dans le presse-papiers.',
                        type = 'success',
                        position = 'top',
                        style = { backgroundColor = '#141517', color = '#d6d6d6' }
                    })
                        lib.setClipboard(appointment.phone_number)
                    end
                end,
                metadata = {
                    {label = 'Action', value = 'Cliquer pour copier'}
                },
            },
            {
                title = 'Supprimer',
                description = 'Supprimer le rendez-vous',
                icon = 'trash-can',
                onSelect = function()
                    local dialog = lib.alertDialog({
                        header = 'Confirmation de suppression',
                        content = 'Êtes-vous sûr de vouloir supprimer ce rendez-vous?',
                        centered = true,
                        cancel = true,
                        labels = {
                            cancel = 'Annuler',
                            confirm = 'Confirmer'
                        },
                    })
                    if dialog == 'confirm' then
                        TriggerServerEvent('appointments:confirmDeleteAppointment', appointment.id)
                    end
                end,
                metadata = {
                    {label = 'Action', value = 'Cliquer pour supprimer'}
                },
            },
        }
    })
    lib.showContext('appointments_submenu')
end

local translateJobs = {
    mechanic = 'Mécano',
    police = 'LSPD',
    ambulance = 'EMS',
    realestate = 'Agence immo',
}

local function CheckAppointement()
lib.callback('appointments:checkExistingAppointment', PlayerId(), function(hasAppointment)
if hasAppointment then
    local appointments = lib.callback('appointments:getAllAppointments')
    if appointments then
        local elements = {
            {
                id = 'appointments_menu',
                title = 'Liste de vos rendez-vous',
                options = {}
            }
        }
        for _, appointment in ipairs(appointments) do
            local phoneDescription = appointment.phone_number or "Numéro non précisé"
            local messageDescription = appointment.message ~= "" and appointment.message or "Aucun message précisé"
            local description = string.format('Message: %s, Téléphone: %s', messageDescription, phoneDescription)
            local jobName = translateJobs[appointment.job] or appointment.job
            local appointmentOption = {
                title = string.format('%s - %s - %s - %s', appointment.date, appointment.time, appointment.appointment_type_label, jobName),
                description = description,
                icon = 'calendar-day',
                onSelect = function()
                    OpenAppointmentDetails(appointment)
                end
            }
            table.insert(elements[1].options, appointmentOption)
        end
        lib.registerContext(elements[1])
        lib.showContext('appointments_menu')
    end
else
    lib.notify({
        title = 'Liste des rendez-vous',
        description = 'Vous n\'avez aucun rendez-vous de prévu.',
        type = 'error',
        position = 'top',
        style = {backgroundColor = '#141517', color = '#d6d6d6'}
    })
end
end)
end



local function OpenAppointments(job)

  local jobDisplayName = getJobDisplayName(job)

    local elements = {
        {
            id = 'appointments_menu',
            title = 'Liste des rendez-vous avec ' .. jobDisplayName,
            options = {}
        }
    }
    lib.callback('appointments:getAppointments', PlayerId(), function(appointments)
        if not appointments or #appointments == 0 then
            lib.notify({
                title = 'Liste des rendez-vous',
                description = 'Il n\'y a aucun rendez-vous planifié avec '.. jobDisplayName,
                type = 'error',
                position = 'top',
                style = {backgroundColor = '#141517', color = '#d6d6d6'}
            })
            return
        end
        elements[1].options = {}
        for _, appointment in ipairs(appointments) do
            local phoneDescription = appointment.phone_number or "Numéro non précisé"
            local messageDescription = appointment.message ~= "" and appointment.message or "Aucun message précisé"
            local description = string.format('Message: %s, Téléphone: %s', messageDescription, phoneDescription)
            local appointmentOption = {
                title = string.format('%s - %s - %s', appointment.date, appointment.time, appointment.appointment_type_label),
                description = description,
                icon = 'calendar-day',
                onSelect = function()
                    OpenAppointmentDetails(appointment)
                end
            }
            table.insert(elements[1].options, appointmentOption)
        end
        lib.registerContext(elements[1])
        lib.showContext('appointments_menu')
    end, job)
end

local peds = {
{
    model = 's_f_m_shop_high',
    coords = vector4(-578.29, -718.01, 36.29, 86.14),
    renderDistance = 5,
    targetOptions = {
        {
            icon = 'fa-solid fa-calendar-plus',
            label = 'Prendre un rendez-vous',
            distance = 2.5,
            canInteract = function(entity, distance, coords, name, bone)
                return true
            end,
            onSelect = function(data)
                TakeAppointement('realestate')
            end
        },
        {
            icon = 'fa-solid fa-calendar-check',
            label = 'Afficher vos rendez-vous',
            distance = 2.5,
            canInteract = function(entity, distance, coords, name, bone)
                return true
            end,
            onSelect = function(data)
                CheckAppointement()
            end
        },
        {
            icon = 'fa-solid fa-list',
            label = 'Consulter les rendez-vous',
            distance = 2.5,
            canInteract = function(entity, distance, coords, name, bone)
                return true
            end,
            groups = { 'realestate' },
            onSelect = function(data)
                OpenAppointments('realestate')
            end
        },
    },
    onSpawn = function(self)
        if Debug then
            for i, v in pairs(self) do
                print(i, v)
            end
        end
    end,
    onDespawn = function(self)
        if Debug then
            for i, v in pairs(self) do
                print(i, v)
            end
        end
    end
},
    {
        model = 's_f_y_cop_01',
        coords = vector4(440.50, -986.33, 30.72, 359.92),
        renderDistance = 5,
        targetOptions = {
            {
                icon = 'fa-solid fa-calendar-plus',
                label = 'Prendre un rendez-vous',
                distance = 5.5,
                canInteract = function(entity, distance, coords, name, bone)
                    return true
                end,
                onSelect = function(data)
                    TakeAppointement('police')
                end
            },
            {
                icon = 'fa-solid fa-calendar-check',
                label = 'Afficher vos rendez-vous',
                distance = 5.5,
                canInteract = function(entity, distance, coords, name, bone)
                    return true
                end,
                onSelect = function(data)
                    CheckAppointement()
                end
            },
            {
                icon = 'fa-solid fa-list',
                label = 'Consulter les rendez-vous',
                distance = 5.5,
                canInteract = function(entity, distance, coords, name, bone)
                    return true
                end,
                groups = { 'police' },
                onSelect = function(data)
                    OpenAppointments('police')
                end
            },
        },
        onSpawn = function(self)
            if Debug then
                for i, v in pairs(self) do
                    print(i, v)
                end
            end
        end,
        onDespawn = function(self)
            if Debug then
                for i, v in pairs(self) do
                    print(i, v)
                end
            end
        end
    },
{
    model = 's_m_y_winclean_01',
    coords = vector4(-352.12, -120.02, 38.89, 66.81),
    renderDistance = 5,
    targetOptions = {
        {
            icon = 'fa-solid fa-calendar-plus',
            label = 'Prendre un rendez-vous',
            distance = 2.5,
            canInteract = function(entity, distance, coords, name, bone)
                return true
            end,
            onSelect = function(data)
                TakeAppointement('mechanic')
            end
        },
        {
            icon = 'fa-solid fa-calendar-check',
            label = 'Afficher vos rendez-vous',
            distance = 2.5,
            canInteract = function(entity, distance, coords, name, bone)
                return true
            end,
            onSelect = function(data)
                CheckAppointement()
            end
        },
        {
            icon = 'fa-solid fa-list',
            label = 'Consulter les rendez-vous',
            distance = 2.5,
            canInteract = function(entity, distance, coords, name, bone)
                return true
            end,
            groups = { 'mechanic' },
            onSelect = function(data)
                OpenAppointments('mechanic')
            end
        },
    },
    onSpawn = function(self)
        if Debug then
            for i, v in pairs(self) do
                print(i, v)
            end
        end
    end,
    onDespawn = function(self)
        if Debug then
            for i, v in pairs(self) do
                print(i, v)
            end
        end
    end
},
    {
        model = 's_m_m_doctor_01',
        coords = vector4(300.81, -578.78, 43.26, 70.93),
        renderDistance = 5,
        targetOptions = {
            {
                icon = 'fa-solid fa-calendar-plus',
                label = 'Prendre un rendez-vous',
                distance = 2.5,
                canInteract = function(entity, distance, coords, name, bone)
                    return true
                end,
                onSelect = function(data)
                    TakeAppointement('ambulance')
                end
            },
            {
                icon = 'fa-solid fa-calendar-check',
                label = 'Afficher vos rendez-vous',
                distance = 2.5,
                canInteract = function(entity, distance, coords, name, bone)
                    return true
                end,
                onSelect = function(data)
                    CheckAppointement()
                end
            },
            {
                icon = 'fa-solid fa-list',
                label = 'Consulter les rendez-vous',
                distance = 2.5,
                canInteract = function(entity, distance, coords, name, bone)
                    return true
                end,
                groups = { 'ambulance' },
                onSelect = function(data)
                    OpenAppointments('ambulance')
                end
            },
        },
        onSpawn = function(self)
            if Debug then
                for i, v in pairs(self) do
                    print(i, v)
                end
            end
        end,
        onDespawn = function(self)
            if Debug then
                for i, v in pairs(self) do
                    print(i, v)
                end
            end
        end
    },
}

--[[
█▀█ █▀▀ █▀▄ █▀   █░░ █▀█ █▀▀ █ █▀▀
█▀▀ ██▄ █▄▀ ▄█   █▄▄ █▄█ █▄█ █ █▄▄
]]

function spawnped(index)
    if not peds[index].ped then
        local pedModel = peds[index].model

        lib.requestModel(pedModel, false)

        local coords = peds[index].coords
        peds[index].ped = CreatePed(5, pedModel, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)

        local currentPed = peds[index].ped
        SetPedDefaultComponentVariation(currentPed)
        FreezeEntityPosition(currentPed, true)
        SetEntityInvincible(currentPed, true)
        SetBlockingOfNonTemporaryEvents(currentPed, true)
        SetPedFleeAttributes(currentPed, 0, 0)

        if peds[index].targetOptions then
            exports.ox_target:addLocalEntity(currentPed, peds[index].targetOptions)
        end

        if peds[index].animation then
            ClearPedTasksImmediately(currentPed)
            lib.requestAnimDict(peds[index].animation.dict, 500)
            TaskPlayAnim(currentPed, peds[index].animation.dict, peds[index].animation.anim, 3.0, -8, -1,
                peds[index].animation.flag, 0, false, false, false)
        end

        if peds[index].scenario then
            ClearPedTasksImmediately(currentPed)
            TaskStartScenarioInPlace(currentPed, peds[index].scenario, 0, false)
        end

        if peds[index].prop then
            local propData = peds[index].prop
            local propModel = joaat(propData.propModel)
            lib.requestModel(propModel, 500)
            local prop = CreateObject(propModel, GetEntityCoords(currentPed), 0, 0, 1, false, false)
            peds[index].prop.entity = prop
            AttachEntityToEntity(
                prop,
                currentPed,
                GetPedBoneIndex(currentPed, 28422),
                propData.rotation.x,
                propData.rotation.y,
                propData.rotation.z,
                propData.offset.x,
                propData.offset.y,
                propData.offset.z,
                true, true, false, true, 0, true
            )
        end

        if peds[index].onSpawn then
            peds[index]:onSpawn()
        end
    end
end

function dismissped(index)
    if peds[index].onDespawn then
        peds[index]:onDespawn()
    end

    if peds[index]?.prop?.entity then
        DeletePed(peds[index].prop.entity)
        peds[index].prop.entity = nil
    end

    exports.ox_target:removeLocalEntity(peds[index].ped)

    DeletePed(peds[index].ped)
    peds[index].ped = nil
end

CreateThread(function()
    for i = 1, #peds do
        local coords = peds[i].coords.xyz

        local point = lib.points.new(coords, peds[i].renderDistance, {
            pedIndex = i,
        })

        function point:onEnter()

        spawnped(self.pedIndex)

        end

        function point:onExit()
            dismissped(self.pedIndex)
        end
    end
end)
