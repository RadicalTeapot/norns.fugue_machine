---@class Event_subscriber
Event_subscriber = {
    ---@type table<table, fun(...)>
    callbacks={}
}

---Constructor
---@return Event_subscriber event_subscriber New instance
function Event_subscriber.new()
    ---@type Event_subscriber
    local self = { callbacks = {} }
    setmetatable(self, {__index = Event_subscriber});
    return self
end

---Subscribe a function to be called when triggered
---@param callback fun(...) Function to call when triggered
---@return table key Key of subscribed function
function Event_subscriber:subscribe(callback)
    local key = {}
    self.callbacks[key] = callback
    return key
end

---Remove a subscribed function
---@param key table Key of subscribed function
function Event_subscriber:unsubscribe(key)
    self.callbacks[key] = nil
end

---Trigger all subscribed functions
---@param ... ... Arguments passed to all subscribed functions
function Event_subscriber:trigger(...)
    for _, v in pairs(self.callbacks) do
        v(...)
    end
end

return Event_subscriber
