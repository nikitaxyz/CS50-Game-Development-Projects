--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.hits = params.hits
    self.highScores = params.highScores
    self.balls = params.balls
    self.level = params.level
    self.powerup = params.powerup
    self.powerupKey = params.powerupKey

    self.recoverPoints = 3000

    -- give ball random starting velocity
    self.balls[1].dx = math.random(-200, 200)
    self.balls[1].dy = math.random(-50, -60)
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)

    for k, ball in pairs(self.balls) do
        if ball.inPlay then
            ball:update(dt)
        end
    end

    if self.hits == 8 then
        if self.powerupKey == false then
            self.powerup = Powerup(10)
        else
            self.powerup = Powerup(math.random(1, 9))
        end
        self.hits = 0
    end

    for k, ball in pairs(self.balls) do
        if ball.inPlay then
            if ball:collides(self.paddle) then
                -- raise ball above paddle in case it goes below it, then reverse dy
                ball.y = self.paddle.y - 8
                ball.dy = -ball.dy

                --
                -- tweak angle of bounce based on where it hits the paddle
                --

                -- if we hit the paddle on its left side while moving left...
                if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                    ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))

                -- else if we hit the paddle on its right side while moving right...
                elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                    ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
                end

                gSounds['paddle-hit']:play()
            end
        end
    end

    if self.powerup then
        if self.powerup:collides(self.paddle) then
            if self.powerup.skin == 10 then
                self.powerupKey = true
            else
                for i = 0, 1 do
                    table.insert(self.balls, Ball())
                    self.balls[#self.balls].skin = math.random(7)
                    self.balls[#self.balls].dx = math.random(-200, 200)
                    self.balls[#self.balls].dy = math.random(-50, -60)
                    self.balls[#self.balls].x = self.balls[#self.balls-1].x
                    self.balls[#self.balls].y = self.balls[#self.balls-1].y
                end
            end
            self.powerup = nil
        end
    end

    for b, ball in pairs(self.balls) do
        if ball.inPlay then
    -- detect collision across all bricks with the ball
            for k, brick in pairs(self.bricks) do

                -- only check collision if we're in play
                if brick.inPlay and ball:collides(brick) then
                    if brick.color == 6 and self.powerupKey == false then
                        break
                    end
                    -- add to score
                    self.score = self.score + (brick.tier * 200 + brick.color * 25)

                    self.hits = self.hits + 1

                    -- trigger the brick's hit function, which removes it from play
                    brick:hit()

                    -- if we have enough points, recover a point of health
                    if self.score > self.recoverPoints then
                        -- can't go above 3 health
                        self.health = math.min(3, self.health + 1)

                        if self.paddle.size < 4 then
                            self.paddle.size = self.paddle.size + 1
                            self.paddle.width = self.paddle.width * 2
                        end

                        -- multiply recover points by 2
                        self.recoverPoints = self.recoverPoints + math.min(100000, self.recoverPoints * 2)

                        -- play recover sound effect
                        gSounds['recover']:play()
                    end

                    -- go to our victory screen if there are no more bricks left
                    if self:checkVictory() then
                        gSounds['victory']:play()

                        gStateMachine:change('victory', {
                            level = self.level,
                            paddle = self.paddle,
                            health = self.health,
                            score = self.score,
                            hits = self.hits,
                            highScores = self.highScores,
                            balls = self.balls,
                            recoverPoints = self.recoverPoints
                        })
                    end

                    --
                    -- collision code for bricks
                    --
                    -- we check to see if the opposite side of our velocity is outside of the brick;
                    -- if it is, we trigger a collision on that side. else we're within the X + width of
                    -- the brick and should check to see if the top or bottom edge is outside of the brick,
                    -- colliding on the top or bottom accordingly
                    --

                    -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                    -- so that flush corner hits register as Y flips, not X flips
                    if ball.x + 2 < brick.x and ball.dx > 0 then

                        -- flip x velocity and reset position outside of brick
                        ball.dx = -ball.dx
                        ball.x = brick.x - 8

                    -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                    -- so that flush corner hits register as Y flips, not X flips
                    elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then

                        -- flip x velocity and reset position outside of brick
                        ball.dx = -ball.dx
                        ball.x = brick.x + 32

                    -- top edge if no X collisions, always check
                    elseif ball.y < brick.y then

                        -- flip y velocity and reset position outside of brick
                        ball.dy = -ball.dy
                        ball.y = brick.y - 8

                    -- bottom edge if no X collisions or top collision, last possibility
                    else

                        -- flip y velocity and reset position outside of brick
                        ball.dy = -ball.dy
                        ball.y = brick.y + 16
                    end

                    -- slightly scale the y velocity to speed up the game, capping at +- 150
                    if math.abs(ball.dy) < 150 then
                        ball.dy = ball.dy * 1.02
                    end

                    -- only allow colliding with one brick, for corners
                    break
                end
            end
        end
    end


    -- if ball goes below bounds, revert to serve state and decrease health
    for b, ball in pairs(self.balls) do
        if ball.inPlay then
            if ball.y >= VIRTUAL_HEIGHT then
                ball.inPlay = false
                local stillInPlay = 0

                for b,ball in pairs(self.balls) do
                    if ball.inPlay then
                        stillInPlay = stillInPlay + 1
                    end
                end

                if stillInPlay == 0 then
                    self.health = self.health - 1
                    gSounds['hurt']:play()

                    if self.health == 0 then
                        gStateMachine:change('game-over', {
                            score = self.score,
                            highScores = self.highScores
                        })
                    else
                        if self.paddle.size > 1 then
                            self.paddle.size = self.paddle.size - 1
                            self.paddle.width = self.paddle.width / 2
                        end
                        gStateMachine:change('serve', {
                            paddle = self.paddle,
                            bricks = self.bricks,
                            health = self.health,
                            hits = self.hits,
                            score = self.score,
                            powerupKey = self.powerupKey,
                            highScores = self.highScores,
                            level = self.level,
                            recoverPoints = self.recoverPoints
                        })
                    end
                end
            end
        end
    end
    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if self.powerup then
        self.powerup:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    if self.powerup then
        self.powerup:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()
    for b, ball in pairs(self.balls) do
        if ball.inPlay then
            ball:render()
        end
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end
    end

    return true
end