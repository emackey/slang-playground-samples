// Ported from: https://www.shadertoy.com/view/MdjGR1

// The MIT License
// Copyright © 2013 Inigo Quilez
// https://www.youtube.com/c/InigoQuilez
// https://iquilezles.org/
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// A test on using ray differentials (only primary rays for now) to choose texture filtering
// footprint, and adaptively supersample/filter the procedural texture/patter (up to a rate
// of 10x10).

// This solves texture aliasing without resorting to full-screen 10x10 supersampling, which would
// involve doing raytracing and lighting 10x10 times (not realtime at all).

// The tecnique should be used to filter every texture independently. The ratio of the supersampling
// could be inveresely proportional to the screen/lighing supersampling rate such that the cost
// of texturing would be constant no matter the final image quality settings.


//===============================================================================================
//===============================================================================================

import playground;

[playground::TIME]
uniform float iTime;

[playground::MOUSE_POSITION]
uniform float4 mousePosition;

const static int MaxSamples = 10;  // 10*10

float3 mytexture( float3 p, float3 n, float matid );

// sample a procedural texture with filtering
float3 sampleTextureWithFilter( in float3 uvw, in float3 ddx_uvw, in float3 ddy_uvw, in float3 nor, in float mid )
{
    int sx = 1 + int( clamp( 4.0*length(ddx_uvw-uvw), 0.0, float(MaxSamples-1) ) );
    int sy = 1 + int( clamp( 4.0*length(ddy_uvw-uvw), 0.0, float(MaxSamples-1) ) );

    float3 no = float3(0.0);

    for( int j=0; j<sy; j++ )
    for( int i=0; i<sx; i++ )
    {
        float2 st = float2( float(i), float(j) ) / float2( float(sx),float(sy) );
        no += mytexture( uvw + st.x*(ddx_uvw-uvw) + st.y*(ddy_uvw-uvw), nor, mid );
    }

    return no / float(sx*sy);
}

float3 sampleTexture( in float3 uvw, in float3 nor, in float mid )
{
    return mytexture( uvw, nor, mid );
}


//===============================================================================================
//===============================================================================================
// noise implementation
//===============================================================================================
//===============================================================================================

float3 hash3( float3 p )
{
    p = float3( dot(p,float3(127.1,311.7, 74.7)),
                dot(p,float3(269.5,183.3,246.1)),
                dot(p,float3(113.5,271.9,124.6)));

    return -1.0 + 2.0*fract(sin(p)*13.5453123);
}

float noise( in float3 p )
{
    float3 i = floor( p );
    float3 f = fract( p );

    float3 u = f*f*(3.0-2.0*f);

    return lerp( lerp( lerp( dot( hash3( i + float3(0.0,0.0,0.0) ), f - float3(0.0,0.0,0.0) ),
                             dot( hash3( i + float3(1.0,0.0,0.0) ), f - float3(1.0,0.0,0.0) ), u.x),
                       lerp( dot( hash3( i + float3(0.0,1.0,0.0) ), f - float3(0.0,1.0,0.0) ),
                             dot( hash3( i + float3(1.0,1.0,0.0) ), f - float3(1.0,1.0,0.0) ), u.x), u.y),
                 lerp( lerp( dot( hash3( i + float3(0.0,0.0,1.0) ), f - float3(0.0,0.0,1.0) ),
                             dot( hash3( i + float3(1.0,0.0,1.0) ), f - float3(1.0,0.0,1.0) ), u.x),
                       lerp( dot( hash3( i + float3(0.0,1.0,1.0) ), f - float3(0.0,1.0,1.0) ),
                             dot( hash3( i + float3(1.0,1.0,1.0) ), f - float3(1.0,1.0,1.0) ), u.x), u.y), u.z );
}

//===============================================================================================
//===============================================================================================
// sphere implementation
//===============================================================================================
//===============================================================================================

float softShadowSphere( in float3 ro, in float3 rd, in float4 sph )
{
    float3 oc = sph.xyz - ro;
    float b = dot( oc, rd );

    float res = 1.0;
    if( b>0.0 )
    {
        float h = dot(oc,oc) - b*b - sph.w*sph.w;
        res = smoothstep( 0.0, 1.0, 2.0*h/b );
    }
    return res;
}

float occSphere( in float4 sph, in float3 pos, in float3 nor )
{
    float3 di = sph.xyz - pos;
    float l = length(di);
    return 1.0 - dot(nor,di/l)*sph.w*sph.w/(l*l);
}

float iSphere( in float3 ro, in float3 rd, in float4 sph )
{
    float t = -1.0;
    float3  ce = ro - sph.xyz;
    float b = dot( rd, ce );
    float c = dot( ce, ce ) - sph.w*sph.w;
    float h = b*b - c;
    if( h>0.0 )
    {
        t = -b - sqrt(h);
    }

    return t;
}

//===============================================================================================
//===============================================================================================
// scene
//===============================================================================================
//===============================================================================================


// spheres
const static float4 sc0 = float4( 0.0,1.0, 0.0, 1.0 );
const static float4 sc1 = float4( 0.0,1.0,14.0, 4.0 );
const static float4 sc2 = float4(-11.0,1.0, 12.0, 4.0 );
const static float4 sc3 = float4( 13.0,1.0,-10.0, 4.0 );

float intersect( float3 ro, float3 rd, out float3 pos, out float3 nor, out float occ, out float matid )
{
    // raytrace
    float tmin = 10000.0;
    nor = float3(0.0);
    occ = 1.0;
    pos = float3(0.0);

    // raytrace-plane
    float h = (0.0-ro.y)/rd.y;
    if( h>0.0 )
    {
        tmin = h;
        nor = float3(0.0,1.0,0.0);
        pos = ro + h*rd;
        matid = 0.0;
        occ = occSphere( sc0, pos, nor ) *
              occSphere( sc1, pos, nor ) *
              occSphere( sc2, pos, nor ) *
              occSphere( sc3, pos, nor );
    }

    // raytrace-sphere
    h = iSphere( ro, rd, sc0 );
    if( h>0.0 && h<tmin )
    {
        tmin = h;
        pos = ro + h*rd;
        nor = normalize(pos-sc0.xyz);
        matid = 1.0;
        occ = 0.5 + 0.5*nor.y;
    }

    h = iSphere( ro, rd, sc1 );
    if( h>0.0 && h<tmin )
    {
        tmin = h;
        pos = ro + tmin*rd;
        nor = normalize(ro+h*rd-sc1.xyz);
        matid = 1.0;
        occ = 0.5 + 0.5*nor.y;
    }

    h = iSphere( ro, rd, sc2 );
    if( h>0.0 && h<tmin )
    {
        tmin = h;
        pos = ro + tmin*rd;
        nor = normalize(ro+h*rd-sc2.xyz);
        matid = 1.0;
        occ = 0.5 + 0.5*nor.y;
    }

    h = iSphere( ro, rd, sc3 );
    if( h>0.0 && h<tmin )
    {
        tmin = h;
        pos = ro + tmin*rd;
        nor = normalize(ro+h*rd-sc3.xyz);
        matid = 1.0;
        occ = 0.5 + 0.5*nor.y;
    }

    return tmin;
}

float3 texCoords( in float3 p )
{
    return 64.0*p;
}

float3 mytexture( float3 p, float3 n, float matid )
{
    p += 0.1;
    float3 ip  = floor(p/20.0);
    float3 fp  = fract(0.5+p/20.0);

    float id = fract(sin(dot(ip,float3(127.1,311.7, 74.7)))*58.5453123);
    id = lerp( id, 0.3, matid );

    float f = fmod( ip.x + fmod(ip.y + fmod(ip.z, 2.0), 2.0), 2.0 );

    float g = 0.5 + 1.0*noise( p * lerp( float3(0.2+0.8*f,1.0,1.0-0.8*f), float3(1.0), matid) );

    g *= lerp( smoothstep( 0.03, 0.04, abs(fp.x-0.5)/0.5 )*
               smoothstep( 0.03, 0.04, abs(fp.z-0.5)/0.5 ),
               1.0,
               matid );

    float3 col = 0.5 + 0.5*sin( 1.0 + 2.0*id + float3(0.0,1.0,2.0) );

    return col * g;
}

void calcCamera( out float3 ro, out float3 ta )
{
    float an = 0.1*iTime;
    ro = float3( 5.5*cos(an), 1.0, 5.5*sin(an) );
    ta = float3( 0.0, 1.0, 0.0 );

}

float3 doLighting( in float3 pos, in float3 nor, in float occ, in float3 rd )
{
    float sh = min( min( min( softShadowSphere( pos, float3(0.57703), sc0 ),
                              softShadowSphere( pos, float3(0.57703), sc1 )),
                              softShadowSphere( pos, float3(0.57703), sc2 )),
                              softShadowSphere( pos, float3(0.57703), sc3 ));
    float dif = clamp(dot(nor,float3(0.57703)),0.0,1.0);
    float bac = clamp(dot(nor,float3(-0.707,0.0,-0.707)),0.0,1.0);
    float3 lin  = dif*float3(1.50,1.40,1.30)*sh;
           lin += occ*float3(0.15,0.20,0.30);
           lin += bac*float3(0.20,0.20,0.20);
           lin += sh*0.8*pow(clamp(dot(reflect(rd,nor),float3(0.57703)),0.0,1.0),12.0);

    return lin;
}
//===============================================================================================
//===============================================================================================
// render
//===============================================================================================
//===============================================================================================

void calcRayForPixel( float2 pix, out float3 resRo, out float3 resRd, int2 iResolution )
{
    float2 p = (-iResolution.xy + 2.0*pix) / iResolution.y;

     // camera movement
    float3 ro, ta;
    calcCamera( ro, ta );
    // camera matrix
    float3 ww = normalize( ta - ro );
    float3 uu = normalize( cross(ww,float3(0.0,1.0,0.0) ) );
    float3 vv = normalize( cross(uu,ww));
    // create view ray
    float3 rd = normalize( p.x*uu + p.y*vv + 1.5*ww );

    resRo = ro;
    resRd = rd;
}


float4 imageMain(uint2 dispatchThreadID, int2 iResolution)
{
    float2 fragCoord = float2(dispatchThreadID);
    float2  p  = (-iResolution.xy + 2.0*fragCoord.xy) / iResolution.y;
    float th = (-iResolution.x + 2.0*mousePosition.x) / iResolution.y;

    if( mousePosition.y<0.01) th = 0.5/ iResolution.y;

    float3 ro, rd, ddx_ro, ddx_rd, ddy_ro, ddy_rd;
    calcRayForPixel( fragCoord.xy + float2(0.0,0.0), ro, rd, iResolution );
    calcRayForPixel( fragCoord.xy + float2(1.0,0.0), ddx_ro, ddx_rd, iResolution );
    calcRayForPixel( fragCoord.xy + float2(0.0,1.0), ddy_ro, ddy_rd, iResolution );

    // trace
    float3 pos, nor;
    float occ, mid;
    float t = intersect( ro, rd, pos, nor, occ, mid );

    float3 col = float3(0.9);
    if( t<100.0 )
    {
#if 1
        // -----------------------------------------------------------------------
        // compute ray differentials by intersecting the tangent plane to the
        // surface.
        // -----------------------------------------------------------------------

        // computer ray differentials
        float3 ddx_pos = ddx_ro - ddx_rd*dot(ddx_ro-pos,nor)/dot(ddx_rd,nor);
        float3 ddy_pos = ddy_ro - ddy_rd*dot(ddy_ro-pos,nor)/dot(ddy_rd,nor);

        // calc texture sampling footprint
        float3     uvw = texCoords(     pos );
        float3 ddx_uvw = texCoords( ddx_pos );
        float3 ddy_uvw = texCoords( ddy_pos );
#else
        // -----------------------------------------------------------------------
        // Because we are in the GPU, we do have access to differentials directly
        // This wouldn't be the case in a regular raytrace.
        // It wouldn't work as well in shaders doing interleaved calculations in
        // pixels (such as some of the 3D/stereo shaders in Shadertoy)
        // -----------------------------------------------------------------------
        float3 uvw = texCoords( pos );

        // calc texture sampling footprint
        float3 ddx_uvw = uvw + ddx( uvw );
        float3 ddy_uvw = uvw + ddy( uvw );
#endif
        // shading
        float3 mate = float3(0.0);

        if( p.x<th )
            mate = sampleTexture( uvw, nor, mid );
        else
            mate = sampleTextureWithFilter( uvw, ddx_uvw, ddy_uvw, nor, mid );

        // lighting
        float3 lin = doLighting( pos, nor, occ, rd );

        // combine lighting with material
        col = mate * lin;

        // fog
        col = lerp( col, float3(0.9), 1.0-exp( -0.0002*t*t ) );
    }

    // gamma correction
    col = pow( col, float3(0.4545) );

    col *= smoothstep( 0.006, 0.008, abs(p.x-th) );

    return float4( col, 1.0 );
}
