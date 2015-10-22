//C# Example

using UnityEngine;
using UnityEditor;
using System.Collections;

class MyWindow : EditorWindow
{
    [MenuItem("Window/My Window")]

    public static void ShowWindow()
    {
        EditorWindow.GetWindow(typeof(MyWindow));
    }

    void OnGUI()
    {
        // The actual window code goes here
    }
}