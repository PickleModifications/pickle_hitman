function lerp(a, b, t) return a + (b-a) * t end

function v3(coords) return vec3(coords.x, coords.y, coords.z), coords.w end

function GetRandomInt(min, max, exclude)
    for i=1, 1000 do 
        local int = math.random(min, max)
        if exclude == nil or exclude ~= int then 
            return int
        end
    end
end

function dprint(...)
    if Config.Debug then
        print(...)
    end
end

function NumberWithCommas(x)
    local left, num, right = string.match(x, '^([^%d]*%d)(%d*)(.-)$')
    return "$" .. left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())
end