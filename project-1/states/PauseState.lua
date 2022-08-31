-- the user can simply press “P” and pause the state of the game

local pause_icon = love.graphics.newImage('pause_icon.png')

PauseState = Class{__includes = BaseState}

function PauseState:enter(params)
    scrolling = false
    self.game_data = params
end

function PauseState:update(dt)
    -- go back to play if p is pressed
    if love.keyboard.wasPressed('p') then
        sounds['music']:play()
        gStateMachine:change('play', {game_data = self.game_data})
    end
end

function PauseState:render()
    -- simply render pause icon to the middle of the screen
    love.graphics.draw(pause_icon, VIRTUAL_WIDTH / 2 - 32, VIRTUAL_HEIGHT / 2 - 32)
end