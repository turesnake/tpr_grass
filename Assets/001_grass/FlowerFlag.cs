using System.Collections;
using System.Collections.Generic;
using UnityEngine;



// 仅用来标记一朵花
public class FlowerFlag : MonoBehaviour
{

    public Transform rootTF;
    public Transform topTF;


    void Start()
    {
        Debug.Assert( rootTF && topTF );
        
    }


}
