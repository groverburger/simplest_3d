-- simplest 3d example
-- written by groverburger february 2021
-- MIT license
--
-- this code is intended to show the simplest possible 3D implementation in Love2D
-- as g3d has become slightly more complicated, looking at just the basics can be helpful
--
-- if you want a more powerful 3D library for Love2D that is still simple to use,
-- feel free to check out g3d:
-- https://github.com/groverburger/g3d

----------------------------------------------------------------------------------------------------
-- simple vector library
----------------------------------------------------------------------------------------------------
-- only three functions are necessary

function NormalizeVector(vector)
    local dist = math.sqrt(vector[1]^2 + vector[2]^2 + vector[3]^2)
    return {
        vector[1]/dist,
        vector[2]/dist,
        vector[3]/dist,
    }
end

function DotProduct(a,b)
    return a[1]*b[1] + a[2]*b[2] + a[3]*b[3]
end

function CrossProduct(a,b)
    return {
        a[2]*b[3] - a[3]*b[2],
        a[3]*b[1] - a[1]*b[3],
        a[1]*b[2] - a[2]*b[1],
    }
end

----------------------------------------------------------------------------------------------------
-- matrix helper functions
----------------------------------------------------------------------------------------------------
-- matrices are just 16 numbers in table, representing a 4x4 matrix
-- an identity matrix is defined as {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}

function IdentityMatrix()
    return {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
end

-- i find rows and columns confusing, so i use coordinate pairs instead
-- this returns a value of a matrix at a specific coordinate
function GetMatrixXY(matrix, x,y)
    return matrix[x + (y-1)*4]
end

-- return the matrix that results from the two given matrices multiplied together
function MatrixMult(a,b)
    local ret = {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0}

    local i = 1
    for y=1, 4 do
        for x=1, 4 do
            ret[i] = ret[i] + GetMatrixXY(a,1,y)*GetMatrixXY(b,x,1)
            ret[i] = ret[i] + GetMatrixXY(a,2,y)*GetMatrixXY(b,x,2)
            ret[i] = ret[i] + GetMatrixXY(a,3,y)*GetMatrixXY(b,x,3)
            ret[i] = ret[i] + GetMatrixXY(a,4,y)*GetMatrixXY(b,x,4)
            i = i + 1
        end
    end

    return ret
end

----------------------------------------------------------------------------------------------------
-- three core matrix functions
----------------------------------------------------------------------------------------------------
-- these construct the matrices that are used for 3d projection

function GetTransformationMatrix(translation, rotation, scale)
    local ret = IdentityMatrix()

    -- translations
    ret[4] = translation[1]
    ret[8] = translation[2]
    ret[12] = translation[3]

    -- rotations
    -- x
    local rx = IdentityMatrix()
    rx[6] = math.cos(rotation[1])
    rx[7] = -1*math.sin(rotation[1])
    rx[10] = math.sin(rotation[1])
    rx[11] = math.cos(rotation[1])
    ret = MatrixMult(ret, rx)

    -- y
    local ry = IdentityMatrix()
    ry[1] = math.cos(rotation[2])
    ry[3] = math.sin(rotation[2])
    ry[9] = -math.sin(rotation[2])
    ry[11] = math.cos(rotation[2])
    ret = MatrixMult(ret, ry)

    -- z
    local rz = IdentityMatrix()
    rz[1] = math.cos(rotation[3])
    rz[2] = -math.sin(rotation[3])
    rz[5] = math.sin(rotation[3])
    rz[6] = math.cos(rotation[3])
    ret = MatrixMult(ret, rz)

    -- scale
    local s = IdentityMatrix()
    s[1] = scale[1]
    s[6] = scale[2]
    s[11] = scale[3]
    ret = MatrixMult(ret, s)

    return ret
end

function GetProjectionMatrix(fov, near, far, aspectRatio)
    local top = near * math.tan(fov/2)
    local bottom = -1*top
    local right = top * aspectRatio
    local left = -1*right
    return {
        2*near/(right-left), 0, (right+left)/(right-left), 0,
        0, 2*near/(top-bottom), (top+bottom)/(top-bottom), 0,
        0, 0, -1*(far+near)/(far-near), -2*far*near/(far-near),
        0, 0, -1, 0
    }
end

function GetViewMatrix(eye, target, down)
    local z = NormalizeVector({eye[1] - target[1], eye[2] - target[2], eye[3] - target[3]})
    local x = NormalizeVector(CrossProduct(down, z))
    local y = CrossProduct(z, x)

    return {
        x[1], x[2], x[3], -1*DotProduct(x, eye),
        y[1], y[2], y[3], -1*DotProduct(y, eye),
        z[1], z[2], z[3], -1*DotProduct(z, eye),
        0, 0, 0, 1,
    }
end

-- the 3d projection shader
-- the most important bit here is the vertex shader, which projects 3d coordinates onto the 2d screen
Shader = love.graphics.newShader [[
    uniform mat4 projectionMatrix;
    uniform mat4 modelMatrix;
    uniform mat4 viewMatrix;

    varying vec4 vertexColor;

    #ifdef VERTEX
        vec4 position(mat4 transform_projection, vec4 vertex_position)
        {
            vertexColor = VertexColor;
            return projectionMatrix * viewMatrix * modelMatrix * vertex_position;
        }
    #endif

    #ifdef PIXEL
        vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 pixcoord)
        {
            vec4 texcolor = Texel(tex, vec2(texcoord.x, 1-texcoord.y));
            if (texcolor.a == 0.0) { discard; }
            return vec4(texcolor)*color*vertexColor;
        }
    #endif
]]

function love.load()
    -- define the data that will be stored in each vertex
    -- if some data is not given, default values will be used
    local vertexFormat = {
        {"VertexPosition", "float", 3},
        {"VertexTexCoord", "float", 2},
        {"VertexNormal", "float", 3},
        {"VertexColor", "byte", 4},
    }

    -- vertices for a simple cube
    -- the numbers on the right are UV coordinates, and are not required
    -- they are required for having textures applied correctly, however
    local verts = {
        {-1, -1, -1, 0,0},
        { 1, -1, -1, 1,0},
        {-1,  1, -1, 0,1},
        { 1,  1, -1, 1,1},
        { 1, -1, -1, 1,0},
        {-1,  1, -1, 0,1},

        {-1, -1,  1, 0,0},
        { 1, -1,  1, 1,0},
        {-1,  1,  1, 0,1},
        { 1,  1,  1, 1,1},
        { 1, -1,  1, 1,0},
        {-1,  1,  1, 0,1},

        {-1, -1, -1, 0,0},
        { 1, -1, -1, 1,0},
        {-1, -1,  1, 0,1},
        { 1, -1,  1, 1,1},
        { 1, -1, -1, 1,0},
        {-1, -1,  1, 0,1},

        {-1,  1, -1, 0,0},
        { 1,  1, -1, 1,0},
        {-1,  1,  1, 0,1},
        { 1,  1,  1, 1,1},
        { 1,  1, -1, 1,0},
        {-1,  1,  1, 0,1},

        {-1, -1, -1, 0,0},
        {-1,  1, -1, 1,0},
        {-1, -1,  1, 0,1},
        {-1,  1,  1, 1,1},
        {-1,  1, -1, 1,0},
        {-1, -1,  1, 0,1},

        { 1, -1, -1, 0,0},
        { 1,  1, -1, 1,0},
        { 1, -1,  1, 0,1},
        { 1,  1,  1, 1,1},
        { 1,  1, -1, 1,0},
        { 1, -1,  1, 0,1},
    }

    -- so that near polygons don't overlap far polygons
    love.graphics.setDepthMode("lequal", true)

    Mesh = love.graphics.newMesh(vertexFormat, verts, "triangles")
    Mesh:setTexture(love.graphics.newImage("texture.png"))
    Timer = 0

    -- initialize the projection and view matrices to simulate a camera
    Shader:send("projectionMatrix", GetProjectionMatrix(math.pi/2, 0.01, 1000, love.graphics.getWidth()/love.graphics.getHeight()))
    Shader:send("viewMatrix", GetViewMatrix({0,0,0}, {0,0,1}, {0,1,0}))
end

function love.update(dt)
    -- using the timer just to rotate the cube over time
    Timer = Timer + dt
end

function love.draw()
    -- draw the mesh using the shader
    Shader:send("modelMatrix", GetTransformationMatrix({0,0,4}, {Timer,Timer,Timer}, {1,1,1}))
    love.graphics.setShader(Shader)
    love.graphics.draw(Mesh)
end
