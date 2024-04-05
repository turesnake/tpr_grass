#ifndef GRASS_WIND
#define GRASS_WIND


#include "utils.hlsl"


// param: uv: 一整个草地 就是一个 [0,1] 区间
// ret: [-1,1]
// float calc_wind( float2 uv, float grassNoise )
// {
//     float2 pos = uv * 35;


//     float time = (_Time.y * 1.5) % 1000.0; // 防止丢失精度

//     time += grassNoise * 0.2;


//     float x = pos.x;

//     x = pos.x + sin( pos.y*0.7 + sin(time*0.6)*6 ) * 2;

//     float w = sin( x * 0.5 + time );
//     //w += sin( x * 1.3 +  time + 1 ) * 0.5;

//     return w;
// }


// grassNoise: [-1,1]
float calc_wind( float2 uv, float grassNoise )
{
    float2 pos = uv * 25; // 35


    float time = (_Time.y * 1.5) % 1000.0; // 防止丢失精度

    time += grassNoise * 0.35; // 增加每颗草起伏的 随机性

    float x = pos.x;

    //x = pos.x + sin( pos.y*0.7 + sin(time*0.6)*6 ) * 2;
    //x = pos.x + sin( (pos.y + sin(time*0.6)*6) * 0.7 ) * 2;

    // 制作一种更加碎的 摆动
    x = pos.x + sin( (pos.y) * 1 + sin(time*0.6)*6 ) * 2;
    x +=        sin( (pos.y) * 2 + sin(time*0.6)*4 ) * 1;
    x +=        sin( (pos.y) * 4 + sin(time*0.6)*2 ) * 0.5;

    float w = sin( x * 0.5 + time );
    //w += sin( x * 1.3 +  time + 1 ) * 0.5;

    return w;
}




// 整个草地, 风的强弱变化
// ret: [0.3,1]
float global_wind_weight()
{
    float time = (_Time.y * 0.5) % 1000.0; // 防止丢失精度

    float r = sin(time);
    r += sin( (time+1) * 2  )*0.6;
    r += sin( (time+3) * 4  )*0.3;

    r = remap( -1, 1, 0.7, 1, r );
    return r;
}




// float calc_wind_2( float2 uv )
// {
//     float time = (_Time.y * 0.6) % 1000.0; // 防止丢失精度
//     //float2 pos = uv * 17;

//     float k = length( uv-float2(0,1) ) * 17 + time;


//     k = sin(k );

//     k = pow(1-abs(k), 2);
    
//     k = remap( 0, 1, 0.1, 0.3, k );

//     return k;

// }



#endif
