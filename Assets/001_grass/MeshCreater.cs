using System;
using System.Collections.Generic;
using Unity.Collections;
using Unity.Jobs;
using UnityEngine;
using UnityEngine.Profiling;

using UnityEngine.Rendering;



public class MeshCreater
{

    static Mesh cachedGrassMesh_Triangle;
    static Mesh cachedGrassMesh_Rect;
    static Mesh cachedGrassMesh_Rect2;
    static Mesh cachedGrassMesh_Diamond;
    static Mesh cachedGrassMesh_Hexagon;





    // 三角形叶片:
    public static Mesh GetGrassMesh_Triangle()
    {
        if (!cachedGrassMesh_Triangle) // 新建
        {
            //if not exist, create a 3 vertices hardcode triangle grass mesh
            cachedGrassMesh_Triangle = new Mesh();

            //single grass (vertices)
            Vector3[] verts = new Vector3[3];
            verts[0] = new Vector3(-0.25f, 0);
            verts[1] = new Vector3(+0.25f, 0);
            verts[2] = new Vector3(-0.0f, 1);
            //single grass (Triangle index)
            int[] trinagles = new int[3] { 2, 1, 0, }; //order to fit Cull Back in grass shader, 顺时针排列的3个顶点

            cachedGrassMesh_Triangle.SetVertices(verts);
            cachedGrassMesh_Triangle.SetTriangles(trinagles, 0);
        }
        return cachedGrassMesh_Triangle;
    }

    
    // 
    //  2 -- 3
    //  |  / |
    //  0 -- 1
    public static Mesh GetGrassMesh_Rect()
    {
        if (!cachedGrassMesh_Rect) // 新建
        {
            //if not exist, create a 3 vertices hardcode triangle grass mesh
            cachedGrassMesh_Rect = new Mesh();

            //single grass (vertices)
            Vector3[] verts = new Vector3[4];
            verts[0] = new Vector3(-0.5f, 0);
            verts[1] = new Vector3( 0.5f, 0);
            verts[2] = new Vector3(-0.5f, 1);
            verts[3] = new Vector3( 0.5f, 1);
            //single grass (Triangle index)
            int[] trinagles = new int[6] { 0, 3, 1, 0, 2, 3 }; //order to fit Cull Back in grass shader, 顺时针排列的3个顶点
            cachedGrassMesh_Rect.SetVertices(verts);
            cachedGrassMesh_Rect.SetTriangles(trinagles, 0);
        }
        return cachedGrassMesh_Rect;
    }


    public static Mesh GetGrassMesh_Rect2()
    {
        if (!cachedGrassMesh_Rect2) // 新建
        {
            //if not exist, create a 3 vertices hardcode triangle grass mesh
            cachedGrassMesh_Rect2 = new Mesh();

            float hf = 0.5f;
            float y = 0.2f;

            //single grass (vertices)
            Vector3[] verts = new Vector3[5];
            verts[0] = new Vector3( -hf,  y, -hf );
            verts[1] = new Vector3(  hf,  y, -hf );
            verts[2] = new Vector3(  0,   0, 0 );
            verts[3] = new Vector3( -hf,  y, hf );
            verts[4] = new Vector3(  hf,  y, hf );

            Vector2[] uvs = new Vector2[5];
            uvs[0] = new Vector2( 0f, 0f );
            uvs[1] = new Vector2( 1f, 0f );
            uvs[2] = new Vector2( 0.5f, 0.5f );
            uvs[3] = new Vector2( 0f, 1f );
            uvs[4] = new Vector2( 1f, 1f );

            //single grass (Triangle index)
            int[] trinagles = new int[] { 
                0,2,1,
                0,3,2,
                1,2,4,
                2,3,4
            };
            cachedGrassMesh_Rect2.SetVertices(verts);
            cachedGrassMesh_Rect2.SetTriangles(trinagles, 0);
            cachedGrassMesh_Rect2.uv = uvs;
        }
        return cachedGrassMesh_Rect2;
    }





    // 菱形叶片, 中间有个长方体; 一共 4 个三角形
    //         5
    //      /     \
    //     3  ---  4
    //     |   /   |
    //     1  ---  2
    //      \     /
    //         0
    public static Mesh GetGrassMesh_Diamond()
    {
        if (!cachedGrassMesh_Diamond) // 新建
        {
            //if not exist, create a 3 vertices hardcode triangle grass mesh
            cachedGrassMesh_Diamond = new Mesh();

            float halfRectH = 0.1f;
            float triangleH = 0.5f - halfRectH;
            float halfW = 0.3f;

            //single grass (vertices)
            Vector3[] verts = new Vector3[6];
            verts[0] = new Vector3( 0f,     0f, 0f );
            verts[1] = new Vector3( -halfW, triangleH, 0f );
            verts[2] = new Vector3( +halfW, triangleH, 0f );
            verts[3] = new Vector3( -halfW, 1f - triangleH, 0f );
            verts[4] = new Vector3( +halfW, 1f - triangleH, 0f );
            verts[5] = new Vector3( 0f,     1f, 0f );

            Vector2[] uvs = new Vector2[6];
            uvs[0] = new Vector2( 0.5f, 0f );
            uvs[1] = new Vector2( 0f,   triangleH );
            uvs[2] = new Vector2( 1f,   triangleH );
            uvs[3] = new Vector2( 0f,   1f - triangleH );
            uvs[4] = new Vector2( 1f,   1f - triangleH );
            uvs[5] = new Vector2( 0.5f, 1f );

            //single grass (Triangle index)
            int[] trinagles = new int[12] { 
                0, 1, 2,
                1, 4, 2, 
                1, 3, 4, 
                3, 5, 4 
            }; //order to fit Cull Back in grass shader, 顺时针排列的3个顶点
            cachedGrassMesh_Diamond.SetVertices(verts);
            cachedGrassMesh_Diamond.SetTriangles(trinagles, 0);
            cachedGrassMesh_Diamond.uv = uvs;
        }
        return cachedGrassMesh_Diamond;
    }




    public static Mesh GetGrassMesh_Hexagon()
    {
        if (!cachedGrassMesh_Hexagon) // 新建
        {
            //if not exist, create a 3 vertices hardcode triangle grass mesh
            cachedGrassMesh_Hexagon = new Mesh();

            float halfX = 0.25f;
            float halfZ = 0.5f;
            float h = 0.2f;

            //single grass (vertices)
            Vector3[] verts = new Vector3[7];
            verts[0] = new Vector3( -halfX,  h, -halfZ );
            verts[1] = new Vector3(  halfX,  h, -halfZ );
            //---
            verts[2] = new Vector3( -2*halfX,  h, 0f );
            verts[3] = new Vector3(  0,       0f,  0f );
            verts[4] = new Vector3(  2*halfX,  h, 0f );
            //--- 
            verts[5] = new Vector3( -halfX,    h,  halfZ );
            verts[6] = new Vector3(  halfX,    h,  halfZ );

            //===
            Vector2[] uvs = new Vector2[7];
            uvs[0] = new Vector2( -halfX,   -halfZ );
            uvs[1] = new Vector2(  halfX,   -halfZ );
            //---
            uvs[2] = new Vector2( -2*halfX,   0f );
            uvs[3] = new Vector2(  0,         0f );
            uvs[4] = new Vector2(  2*halfX,   0f );
            //--- 
            uvs[5] = new Vector2( -halfX,      halfZ );
            uvs[6] = new Vector2(  halfX,      halfZ );
            for( int i=0; i<uvs.Length; i++ ) 
            {
                uvs[i] += new Vector2( 0.5f, 0.5f );
            }
            
            //single grass (Triangle index)
            int[] trinagles = new int[] { 
                0, 3, 1,
                0, 2, 3,
                1, 3, 4, 
                2, 5, 3, 
                3, 5, 6, 
                3, 6, 4
            };
            cachedGrassMesh_Hexagon.SetVertices(verts);
            cachedGrassMesh_Hexagon.SetTriangles(trinagles, 0);
            cachedGrassMesh_Hexagon.uv = uvs;
        }
        return cachedGrassMesh_Hexagon;
    }






}


