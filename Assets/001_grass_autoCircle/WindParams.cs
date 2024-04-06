using System.Collections;
using System.Collections.Generic;
using UnityEngine;




/*
    统一管理 风/麦浪 参数;
    现在 草 和 多组花 都会用到这组参数; 使用本组件来强制统一参数信息
*/
public class WindParams : MonoBehaviour
{

    //_wheatWaveDegree("麦浪方向夹角(0,360)", Range(0,360)) = 0
    //_Wind("x:麦浪运动速度(可正负); y:风力大小;", Vector) = ( 1.5, 2, 0, 0 )

    [Header("麦浪方向夹角(0,360)")]
    [Range(0f,360f)]
    public float wheatWaveDegree = 0f;

    [Header("麦浪运动速度(可正负); 推荐值:1.5f")]
    public float wheatWaveSpeed = 1f;

    [Header("风力大小, 此值越大草的摇动效果越剧烈; 推荐值:2f")]
    public float windPower = 2f;



    public Vector4 GetWindParams() 
    {
        return new Vector4( wheatWaveDegree, wheatWaveSpeed, windPower, 0f );
    }
}
