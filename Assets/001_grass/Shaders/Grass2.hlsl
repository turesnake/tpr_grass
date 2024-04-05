#ifndef GRASS2
#define GRASS2


#include "utils.hlsl"




// param: rootPosWS_:           草根 posWS
// param: dirDegree_:           麦浪方向夹角(角度), 区间:[0,360]; 时钟0点(0,1)为0度, 顺时针为正逆时针为负; 
// param: wheatWaveGridSize_:   麦浪网格边长; 
// param: time_:                时间基数;
// param: speed_:               麦浪运动速度, 写入负值来让运动方向逆向;
float2 GetWheatWaveUV( float3 rootPosWS_, float dirDegree_, float wheatWaveGridSize_, float time_, float speed_ ) 
{
    float2 pos = Rotate2D( rootPosWS_.xz, dirDegree_ );
    pos = pos + float2(1,0) * time_ * speed_; 
    float2 uv = frac( pos / wheatWaveGridSize_ );
    return uv;
}



float3 GetWindDir( float dirDegree_, float speed_ ) 
{
    float2 ret = Degree2Dir(dirDegree_) * (speed_ > 0.0 ? 1 : -1);
    return normalize(float3( ret.x, 0, ret.y ));
}






#endif
