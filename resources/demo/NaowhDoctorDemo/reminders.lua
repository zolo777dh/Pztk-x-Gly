local addonName, ns = ...

function ns.CreateReminder(reminderId, data)
    SetReminder(reminderId, data)
    print("Reminder created")
end

-- Legacy call to review for Retail. Return values need migration, not a rename.
local name = GetSpellInfo(12345)
