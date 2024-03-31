#ifndef TPR_UTILS
#define TPR_UTILS


// ret: [0,1]
float hash12(float2 p)
{
    float3 p3  = frac(float3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z); // [0,1]
}


// x 在区间[t1,t2] 中, 求区间[s1,s2] 中同比例的点的值;
float remap( float t1, float t2, float s1, float s2, float x )
{
    return ((x - t1) / (t2 - t1) * (s2 - s1) + s1);
}

float Deg2Rad( float deg_ )
{
    return deg_ * (3.14159 / 180.0);
}

float Rad2Deg( float rad_ )
{
    return rad_ * (180.0 / 3.14159);
}



float2 Rotate2D( float2 pos_, float degree_ ) 
{
    float th = Deg2Rad(degree_);
    float2x2 mtx = float2x2(
        cos(th), -sin(th),
        sin(th),  cos(th)
    );
    return mul( mtx, pos_ );
}


float3 Rotate3D_yAxis( float3 pos_, float degree_ ) 
{
    float th = Deg2Rad(degree_);
    float3x3 mtx = float3x3(
        cos(th), 0,  sin(th),
        0,       1,    0,
        -sin(th), 0,  cos(th)
    );
    // float3x3 mtx = float3x3(
    //     1, 0,  0,
    //     0, 1,  0,
    //     0, 0,  1
    // );
    return mul( mtx, pos_ );
}




// param: deg: 与 (0,1) 方向的夹角; (时钟0点方向, 顺时针为正, 逆时针为负)
float2 Degree2Dir( float deg_ )
{
    float rad = Deg2Rad(deg_);
    return float2(sin(rad),cos(rad));
}










#endif
