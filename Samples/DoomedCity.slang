// Just like Missile Command!!!!! (sort of)
// Original by Alan Mackey, from https://glslsandbox.com/e#28696.9
// License: https://creativecommons.org/publicdomain/zero/1.0/

import playground;

[playground::BLACK_SCREEN(2.0, 2.0)]
RWTexture2D<float> tex_current;

[playground::BLACK_SCREEN(2.0, 2.0)]
RWTexture2D<float> tex_previous;

[playground::ZEROS(8)]
RWStructuredBuffer<float> variables;

[playground::TIME]
uniform float time;

[playground::FRAME_ID]
uniform float frame;

[playground::MOUSE_POSITION]
uniform float4 mousePosition;

const static float onePoint = 1.0 / 255.0;

const static float aVoid = 0.9;
const static float aSplode = 0.8;
const static float aBombL = 0.7;
const static float aBombR = 0.6;
const static float aShot = 0.5;
const static float aTower = 0.4;
const static float aNuke = 0.3;

float4 getColor(int2 iPos, int2 imageSize)
{
    // NOTE: Gets color from previous, not current.

    iPos = clamp(iPos, int2(0), imageSize - 1);
    return float4(
        tex_previous[iPos],
        tex_previous[iPos + int2(imageSize.x, 0)],
        tex_previous[iPos + int2(0, imageSize.y)],
        tex_previous[iPos + imageSize]);
}

void setColor(int2 iPos, int2 imageSize, float4 in_color)
{
    // NOTE: Sets current color, not previous.

    float4 color = clamp(in_color, 0, 1);
    iPos = clamp(iPos, int2(0), imageSize - 1);
    tex_current[iPos] = color.r;
    tex_current[iPos + int2(imageSize.x, 0)] = color.g;
    tex_current[iPos + int2(0, imageSize.y)] = color.b;
    tex_current[iPos + imageSize] = color.a;
}

[shader("compute")]
[numthreads(16, 16, 1)]
[playground::CALL::SIZE_OF("tex_current")]
void currentToPrevious(uint2 dispatchThreadId: SV_DispatchThreadID)
{
    // Copy all current colors to previous

    uint imageW;
    uint imageH;
    tex_previous.GetDimensions(imageW, imageH);

    int2 iPos = int2(dispatchThreadId);
    int2 imageSize = int2(imageW, imageH);

    if (iPos.x > imageSize.x || iPos.y > imageSize.y)
        return;

    tex_previous[iPos] = tex_current[iPos];
}

float rand(int seed, int2 iPos) {
    // Random float based on time, location and seed
    return fract(sin(time*23.254 + float(seed)*438.5345 - iPos.x*37.2342 + iPos.y * 73.25423)*3756.234);
}

float yRand(int2 iPos) {
    // Random float based on time and Y coord
    return fract(sin(time*23.254 + iPos.y*37.2342)*3756.234);
}

bool is_(float4 px, float material) {
    // Test for specific material
    return (abs(px.a - material) < 0.045);
}

float4 px(int dx, int dy, int2 iPos, int2 imageSize) {
    // Fetch pixel RGBA at relative location
    int2 posDelta = iPos - int2(dx, dy);
    if ((posDelta.x < 0.0) || (posDelta.y < 0.0) || (posDelta.x >= imageSize.x) || (posDelta.y >= imageSize.y)) {
        return float4(0.0);
    }
    return getColor(posDelta, imageSize);
}

float4 imageAdvance(int2 iPos, int2 imageSize)
{
    float4 fragColor = float4(0.0, 0.0, 0.0, 1.0);
    float2 position = float2(iPos) / imageSize;
    float2 mouse = float2(mousePosition.x, imageSize.y - mousePosition.y - 1) / imageSize;
	float2 mDist = float2(iPos) - mouse * imageSize;
	position.x -= 0.5;
	position.x *= float(imageSize.x)/imageSize.y;

    // Mouse status
    if (iPos.x == 0 && iPos.y == 0 && mousePosition.z >= 0) {
        // Last time mouse was seen "up" (not clicked or held)
        variables[0] = frame;
    }
    else if (mousePosition.z < 0) {
        // Mouse causes shots in regular intervals
        float lastMouseUpFrame = variables[0];
        if ((length(mDist) < 2.5) && (mouse.y > 0.25) && (frame - lastMouseUpFrame < 1.25))
        {
            fragColor.rgb = float3(1.0, 1.0-mouse.y, 1.0-mouse.y);
            fragColor.a = aShot;
            return fragColor;
        }
	}

	// Test -- is this pixel in a bomb's path?
	float4 bombPath = float4(-1);
	float4 bombL = px((yRand(iPos)<0.5)?0:-1,-1,iPos,imageSize);
	if (is_(bombL, aBombL)) {bombPath = bombL;}
	float4 bombR = px((yRand(iPos)<0.5)?0:1,-1,iPos,imageSize);
	if (is_(bombR, aBombR)) {bombPath = bombR;}

	// Neighbor pixels
	float4 here = px(0,0,iPos,imageSize);
	float4 pxl = px(-1,0,iPos,imageSize);
	float4 pxr = px(1,0,iPos,imageSize);
	float4 pxu = px(0,1,iPos,imageSize);
	float4 pxd = px(0,-1,iPos,imageSize);

	// Growing explosion wave
	float4 isSplode = float4(-1.0);
	if ((rand(1,iPos)<pxl.r) && (is_(pxl, aSplode))) {isSplode = pxl;}
	if ((rand(2,iPos)<pxr.r) && (is_(pxr, aSplode)) && (pxr.r > isSplode.r)) {isSplode = pxr;}
	if ((rand(3,iPos)<pxu.r) && (is_(pxu, aSplode)) && (pxu.r > isSplode.r)) {isSplode = pxu;}
	if ((rand(4,iPos)<pxd.r) && (is_(pxd, aSplode)) && (pxd.r > isSplode.r)) {isSplode = pxd;}
	if (is_(here, aSplode) && (here.r > isSplode.r)) {isSplode = here;}
	isSplode.rgb -= float3(1.0/255.0, 2.0/255.0, 4.0/255.0) * ((17.0 * rand(5,iPos))-1.0);
	if ((isSplode.a > 0.0) && (isSplode.r > 0.0) && !(is_(here, aTower))) {
		if ((bombPath.a > 0.0) || (is_(here, aShot))) {
			// Explosions trigger player shots and enemy bombs to explode
			fragColor.rgb = float3(1.0);
		} else {
			fragColor.rgb = isSplode.rgb;
		}
		fragColor.a = aSplode;
		return fragColor;
	}

	// Shots glow brighter until they explode
	if (is_(here, aShot)) {
		fragColor.rgb = here.rgb + 0.04*rand(83,iPos);
		fragColor.a = ((here.g >= 1.0) || (bombPath.a > 0.0)) ? aSplode : aShot;
		return fragColor;
	}

	// Bombs drop randomly from top row
	if ((abs(imageSize.y - iPos.y - 1.0) < 1.0) && (rand(30,iPos) < 0.1) && (rand(33,iPos) < 0.1) && (rand(38,iPos) < 0.05) && (rand(40,iPos) < 0.03)) {
		fragColor.rgb = float3(0.0, 0.5+rand(25,iPos), 0.0);
		fragColor.a = (rand(88,iPos) < (float(iPos.x)/imageSize.x)) ? aBombL : aBombR;
		return fragColor;
	}

	// Bombs fall downwards diagonally
	if (bombPath.a > 0.0) {
		if (is_(here, aTower)) {
			fragColor.rgb = float3(1.0);
			fragColor.a = aNuke;
			return fragColor;
		}
		fragColor.rgb = float3(0.0, 0.5+rand(25,iPos), 0.0);
		fragColor.a = bombPath.a;
		return fragColor;
	}

	// Growing nuke wave
	float4 isNuke = float4(-1.0);
	if ((rand(1,iPos)<pxl.r) && (is_(pxl, aNuke))) {isNuke = pxl;}
	if ((rand(2,iPos)<pxr.r) && (is_(pxr, aNuke)) && (pxr.r > isNuke.r)) {isNuke = pxr;}
	if ((rand(3,iPos)*0.1<pxu.r) && (is_(pxu, aNuke)) && (pxu.r > isNuke.r)) {isNuke = pxu;}
	if ((rand(4,iPos)<pxd.r) && (is_(pxd, aNuke)) && (pxd.r > isNuke.r)) {isNuke = pxd; isNuke.rgb -= rand(53,iPos) * 0.025;}
	if (is_(here, aNuke) && (here.r > isNuke.r)) {isSplode = here;}
	isNuke.rgb -= float3(2.0/255.0, 1.0/255.0, 4.0/255.0) * ((17.0 * rand(5,iPos))-2.3);
	if ((isNuke.a >= onePoint) && (isNuke.g >= onePoint)) {
		fragColor.rgb = isNuke.rgb;
		fragColor.a = aNuke;
		return fragColor;
	}

	// Towers persist
	if (is_(here, aTower) || (iPos.y < 1.1)) {
		fragColor = here;
		fragColor.a = aTower;
		return fragColor;
	}

	// Tower setup
	if (here.a < onePoint) {
		float bNum = floor(position.x * 40.0);
		float bHeight = 0.01 + 0.18 * fract(sin(bNum)*37.234234);
		if (position.y < bHeight) {
			fragColor.rgb = float3(0);
			fragColor.a = aTower;
			return fragColor;
		}
	}

	// Bombs leave trails
	if ((here.g > here.r) && (here.b < onePoint)) {
		fragColor.rgb = here.rgb - 0.05 * rand(55,iPos);
		fragColor.a = aVoid;
		return fragColor;
	}

	// Sky glow
	float2 glow = position;
	glow.y *= 2.5;
	fragColor.rgb = float3(0.0, 0.05, 0.15) + float3(0.25, 0.12, 0.1) * (1.0-length(glow)) + float3(1.0/255.0)*rand(25,iPos);
	float line = (0.005 - abs(0.25 - float(iPos.y)/imageSize.y)) / 0.01;
	if (line > 0.0) {fragColor.rgb += float3(0.1, 0.2, 0.4) * line;}
	fragColor.a = aVoid;
    return fragColor;
}

float4 imageMain(uint2 dispatchThreadID, int2 screenSize)
{
    uint imageW1;
    uint imageH1;
    tex_current.GetDimensions(imageW1, imageH1);

    uint imageW2;
    uint imageH2;
    tex_previous.GetDimensions(imageW2, imageH2);

    int2 iPos = int2(dispatchThreadID);
    int2 imageSize = int2(min(imageW1, imageW2) / 2, min(imageH1, imageH2) / 2);
    imageSize = min(screenSize, imageSize);

    float4 fragColor = imageAdvance(iPos, imageSize);
    setColor(iPos, imageSize, fragColor);

    return float4(fragColor.rgb, 1.0);
}
