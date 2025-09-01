// Originally from ShaderToy:
// https://www.shadertoy.com/view/ldl3W8

// The MIT License
// Copyright © 2013 Inigo Quilez
// https://www.youtube.com/c/InigoQuilez
// https://iquilezles.org/
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// I've not seen anybody out there computing correct cell interior distances for Voronoi
// patterns yet. That's why they cannot shade the cell interior correctly, and why you've
// never seen cell boundaries rendered correctly.
//
// However, here's how you do mathematically correct distances (note the equidistant and non
// degenerated grey isolines inside the cells) and hence edges (in yellow):
//
// https://iquilezles.org/articles/voronoilines

import playground;

[playground::TIME]
uniform float iTime;

// PNG of 64x64 RGB noise
[playground::URL("data:image/png;base64,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")]
[format("rgba8")]
Texture2D<float4> myImage;

[playground::SAMPLER]
SamplerState sampler;

#define ANIMATE

float2 hash2( float2 p )
{
    // texture based white noise
    return myImage.SampleLevel(sampler, (p+0.5)/32.0, 0.0 ).xy;

    // procedural white noise
    //return fract(sin(float2(dot(p,float2(127.1,311.7)),dot(p,float2(269.5,183.3))))*43758.5453);
}

float3 voronoi( in float2 x )
{
    float2 ip = floor(x);
    float2 fp = fract(x);

    //----------------------------------
    // first pass: regular voronoi
    //----------------------------------
    float2 mg, mr;

    float md = 8.0;
    for( int j=-1; j<=1; j++ )
    for( int i=-1; i<=1; i++ )
    {
        float2 g = float2(float(i),float(j));
        float2 o = hash2( ip + g );
#ifdef ANIMATE
        o = 0.5 + 0.5*sin( iTime + 6.2831*o );
#endif
        float2 r = g + o - fp;
        float d = dot(r,r);

        if( d<md )
        {
            md = d;
            mr = r;
            mg = g;
        }
    }

    //----------------------------------
    // second pass: distance to borders
    //----------------------------------
    md = 8.0;
    for( int j=-2; j<=2; j++ )
    for( int i=-2; i<=2; i++ )
    {
        float2 g = mg + float2(float(i),float(j));
        float2 o = hash2( ip + g );
#ifdef ANIMATE
        o = 0.5 + 0.5*sin( iTime + 6.2831*o );
#endif
        float2 r = g + o - fp;

        if( dot(mr-r,mr-r)>0.00001 )
            md = min( md, dot( 0.5*(mr+r), normalize(r-mr) ) );
    }

    return float3( md, mr );
}

float4 imageMain(uint2 dispatchThreadID, int2 screenSize)
{
    float2 p = float2(dispatchThreadID) / screenSize.x;

    float3 c = voronoi( 8.0*p );

    // isolines
    float3 col = c.x*(0.5 + 0.5*sin(64.0*c.x))*float3(1.0);
    // borders
    col = lerp( float3(1.0,0.6,0.0), col, smoothstep( 0.04, 0.07, c.x ) );
    // feature points
    float dd = length( c.yz );
    col = lerp( float3(1.0,0.6,0.1), col, smoothstep( 0.0, 0.12, dd) );
    col += float3(1.0,0.6,0.1)*(1.0-smoothstep( 0.0, 0.04, dd));

    return float4(col,1.0);
}
