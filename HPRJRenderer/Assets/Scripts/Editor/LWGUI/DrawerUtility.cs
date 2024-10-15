using System.Collections;
using System.Collections.Generic;
using System;
using UnityEditor;
using UnityEngine;
using UnityEngine.Events;
using System.IO;
using UnityEngine.Rendering;

using RenderQueue = UnityEngine.Rendering.RenderQueue;

namespace JTRP.ShaderDrawer
{
    public class GUIData
    {
        public static Dictionary<string, bool> group = new Dictionary<string, bool>();
        public static Dictionary<string, bool> keyWord = new Dictionary<string, bool>();
    }

    public class LWGUI : ShaderGUI
    {
        public MaterialProperty[] props;
        public MaterialEditor materialEditor;

        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
        {
            this.props = props;
            this.materialEditor = materialEditor;

            base.OnGUI(materialEditor, props);
        }

        public static MaterialProperty FindProp(string propertyName, MaterialProperty[] properties,
            bool propertyIsMandatory = false)
        {
            return FindProperty(propertyName, properties, propertyIsMandatory);
        }
    }

    public class Func
    {
        public static void TurnColorDraw(Color useColor, UnityAction action)
        {
            var c = GUI.color;
            GUI.color = useColor;
            if (action != null)
                action();
            GUI.color = c;
        }

        public static string GetKeyWord(string keyWord, string propName)
        {
            string k;
            if (keyWord == "" || keyWord == "__")
            {
                k = propName.ToUpperInvariant() + "_ON";
            }
            else
            {
                k = keyWord.ToUpperInvariant();
            }

            return k;
        }

        /// <summary>
        /// 字符串是否是关键字开头
        /// </summary>
        /// <param name="checkStr"></param>
        /// <returns></returns>
        public static bool IsKeyWordAtBeginning(string checkStr)
        {
            if (string.IsNullOrEmpty(checkStr))
                return false;
            return GUIData.keyWord.ContainsKey(checkStr.Split('#')[0]);
        }

        /// <summary>
        /// 是否包含激活的关键字
        /// </summary>
        /// <param name="checkStr"></param>
        /// <returns></returns>
        public static bool IsIncludeEnabledKeyWord(string checkStr, out bool hasValidKeyWord)
        {
            hasValidKeyWord = false;
            if (string.IsNullOrEmpty(checkStr))
                return false;
            string[] strArray = checkStr.Split('#');
            foreach (string str in strArray)
            {
                if (GUIData.keyWord.ContainsKey(str))
                {
                    hasValidKeyWord = true;
                    if (GUIData.keyWord[str])
                        return true;
                }
            }

            return false;
        }

        public static bool Foldout(ref bool display, bool value, bool hasToggle, string title)
        {
            var style = new GUIStyle("ShurikenModuleTitle"); // BG
            style.font = EditorStyles.boldLabel.font;
            style.fontSize = EditorStyles.boldLabel.fontSize + 3;
            style.border = new RectOffset(15, 7, 4, 4);
            style.fixedHeight = 30;
            style.contentOffset = new Vector2(50f, 0f);

            var rect = GUILayoutUtility.GetRect(16f, 25f, style); // Box
            rect.yMin -= 10;
            rect.yMax += 10;
            GUI.Box(rect, "", style);

            GUIStyle titleStyle = new GUIStyle(EditorStyles.boldLabel); // Font
            titleStyle.fontSize += 2;

            EditorGUI.PrefixLabel(
                new Rect(
                    hasToggle ? rect.x + 50f : rect.x + 25f,
                    rect.y + 6f, 13f, 13f), // title pos
                new GUIContent(title),
                titleStyle);

            var triangleRect = new Rect(rect.x + 4f, rect.y + 8f, 13f, 13f); // triangle

            var clickRect = new Rect(rect); // click
            clickRect.height -= 15f;

            var toggleRect = new Rect(triangleRect.x + 20f, triangleRect.y + 0f, 13f, 13f);

            var e = Event.current;
            if (e.type == EventType.Repaint)
            {
                EditorStyles.foldout.Draw(triangleRect, false, false, display, false);
            }

            if (hasToggle)
            {
                if (EditorGUI.showMixedValue)
                    EditorGUI.Toggle(toggleRect, "", false, new GUIStyle("ToggleMixed"));
                else
                    value = EditorGUI.Toggle(toggleRect, "", value);
            }

            if (e.type == EventType.MouseDown && clickRect.Contains(e.mousePosition))
            {
                display = !display;
                e.Use();
            }

            return value;
        }

        public static void PowerSlider(MaterialProperty prop, float power, Rect position, GUIContent label)
        {
            int controlId = GUIUtility.GetControlID("EditorSliderKnob".GetHashCode(), FocusType.Passive, position);
            float left = prop.rangeLimits.x;
            float right = prop.rangeLimits.y;
            float start = left;
            float end = right;
            float value = prop.floatValue;
            float originValue = prop.floatValue;

            if ((double)power != 1.0)
            {
                start = Func.PowPreserveSign(start, 1f / power);
                end = Func.PowPreserveSign(end, 1f / power);
                value = Func.PowPreserveSign(value, 1f / power);
            }

            EditorGUI.BeginChangeCheck();

            var labelWidth = EditorGUIUtility.labelWidth;
            EditorGUIUtility.labelWidth = 0;

            Rect position2 = EditorGUI.PrefixLabel(position, label);
            position2 = new Rect(position2.x, position2.y, position2.width - EditorGUIUtility.fieldWidth - 5,
                position2.height);

            if (position2.width >= 50f)
                value = GUI.Slider(position2, value, 0.0f, start, end, GUI.skin.horizontalSlider,
                    !EditorGUI.showMixedValue ? GUI.skin.horizontalSliderThumb : (GUIStyle)"SliderMixed", true,
                    controlId);

            if ((double)power != 1.0)
                value = Func.PowPreserveSign(value, power);

            position.xMin += position.width - SubDrawer.propRight;
            value = EditorGUI.FloatField(position, value);

            EditorGUIUtility.labelWidth = labelWidth;
            if (value != originValue)
                prop.floatValue = Mathf.Clamp(value, Mathf.Min(left, right), Mathf.Max(left, right));
        }

        public static MaterialProperty[] GetProperties(MaterialEditor editor)
        {
            if (editor.customShaderGUI != null && editor.customShaderGUI is LWGUI)
            {
                LWGUI gui = editor.customShaderGUI as LWGUI;
                return gui.props;
            }
            else
            {
                Debug.LogWarning("Please add \"CustomEditor \"JTRP.ShaderDrawer.LWGUI\"\" to the end of your shader!");
                return null;
            }
        }

        public static float PowPreserveSign(float f, float p)
        {
            float num = Mathf.Pow(Mathf.Abs(f), p);
            if ((double)f < 0.0)
                return -num;
            return num;
        }

        public static Color RGBToHSV(Color color)
        {
            float h, s, v;
            Color.RGBToHSV(color, out h, out s, out v);
            return new Color(h, s, v, color.a);
        }

        public static Color HSVToRGB(Color color)
        {
            var c = Color.HSVToRGB(color.r, color.g, color.b);
            c.a = color.a;
            return c;
        }

        public static void SetShaderKeyWord(UnityEngine.Object[] materials, string keyWord, bool isEnable)
        {
            foreach (Material m in materials)
            {
                if (m.IsKeywordEnabled(keyWord))
                {
                    if (!isEnable) m.DisableKeyword(keyWord);
                }
                else
                {
                    if (isEnable) m.EnableKeyword(keyWord);
                }
            }
        }

        public static void SetShaderKeyWord(Material[] materials, string keyWord, bool isEnable)
        {
            foreach (Material m in materials)
            {
                if (m.IsKeywordEnabled(keyWord))
                {
                    if (!isEnable) m.DisableKeyword(keyWord);
                }
                else
                {
                    if (isEnable) m.EnableKeyword(keyWord);
                }

            }
        }

        public static void SetShaderKeyWord(UnityEngine.Object[] materials, string[] keyWords, int index)
        {
            Debug.Assert(keyWords.Length >= 1 && index < keyWords.Length && index >= 0,
                $"KeyWords:{keyWords} or Index:{index} Error! ");
            for (int i = 0; i < keyWords.Length; i++)
            {
                SetShaderKeyWord(materials, keyWords[i], index == i);
                if (GUIData.keyWord.ContainsKey(keyWords[i]))
                {
                    GUIData.keyWord[keyWords[i]] = index == i;
                }
                else
                {
                    Debug.LogError("KeyWord not exist! Throw a shader error to refresh the instance.");
                }
            }
        }

        public static void SetSupportingCharacter(UnityEngine.Object[] materials)
        {
            foreach (Material material in materials)
            {
                float isSupChar = 0f;

                if (material.HasProperty("_SupportingCharacterIndex"))
                {
                    isSupChar = material.GetFloat("_SupportingCharacterIndex");
                }


                if (isSupChar >= 1)
                    material.EnableKeyword("_IsSupCharacter");
                else
                    material.DisableKeyword("_IsSupCharacter");
            }
        }

        public static void SetOnSkinPropChange(UnityEngine.Object[] materials, int skinMode)
        {
            foreach (Material material in materials)
            {
                switch (skinMode)
                {
                    case 0:
                        material.SetInt("_ClothStencilEnum", 8);
                        material.SetShaderPassEnabled("ClothStencil", false);
                        material.SetInt("_ClothStencilShadowEnum", 8);
                        break;
                    case 1:
                        material.SetInt("_ClothStencilEnum", 3);
                        material.SetShaderPassEnabled("ClothStencil", true);
                        material.SetInt("_ClothStencilShadowEnum", 5);
                        break;
                }
                
            }
        }

        /// <summary>
        ///   <para>Set relevant properties once Render Mode is changed</para>
        /// </summary>
        /// <param name="materials">Arrays of materials of all the object being inspected..</param>
        /// <param name="mode">The type of current Render Mode.</param>
        /// <param name="isTransparentShadowCaster">If true then the targeted materials should be treated as a transparent caster, and its Render Queue will be set 3010 to enable relevant render passes.</param>
        public static void SetOnRenderingModeChange(UnityEngine.Object[] materials, int mode,
            bool isTransparentShadowCaster = false)
        {
            foreach (Material material in materials)
            {
                float alphaTest = 0f;
                int queueOffset = 0;
                bool isST = false;
                if (material.HasProperty("_AlphaTest"))
                    alphaTest = material.GetFloat("_AlphaTest");
                if (material.HasProperty("_QueueOffset"))
                    queueOffset = (int)material.GetFloat("_QueueOffset");
                if (material.HasProperty("_StandardMode"))
                    isST = (material.GetFloat("_StandardMode") == 4 || material.GetFloat("_StandardMode") == 5);
                
                switch (mode)
                {
                    case 0:
                        material.SetOverrideTag("RenderType", alphaTest > 0.5f ? "TransparentCutout" : "Opaque");
                        material.SetInt("_SrcBlend", (int)BlendMode.One);
                        material.SetInt("_DstBlend", (int)BlendMode.Zero);
                        material.SetInt("_ZWrite", 1);
                        //material.SetFloat(" _AlphaPremultiply", 0.0f);
                        material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                        if (isST == false)
                        {
                            material.renderQueue =
                                (int)(alphaTest > 0.5f ? RenderQueue.AlphaTest : RenderQueue.Geometry) + queueOffset;
                        }
                        material.SetShaderPassEnabled("SpecialTranspPreZ", false);
                        material.SetShaderPassEnabled("ShadowCaster", true);
                        material.SetShaderPassEnabled("CharacterShadowCaster", true);
                        material.SetShaderPassEnabled("CharacterClothShadowCaster", true);
                        break;
                    case 1:
                        material.SetOverrideTag("RenderType", "Transparent");
                        material.SetInt("_SrcBlend", (int)BlendMode.SrcAlpha);
                        material.SetInt("_DstBlend", (int)BlendMode.OneMinusSrcAlpha);
                        material.SetInt("_ZWrite", 0);
                        //material.SetFloat(" _AlphaPremultiply", 0.0f);
                        material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                        if (isST == false)
                        {
                            if (isTransparentShadowCaster == true)
                            {
                                material.renderQueue = (int)RenderQueue.Transparent + 20;
                            }
                            else
                                material.renderQueue = (int)RenderQueue.Transparent + queueOffset;
                        }
                        else
                        {
                            material.renderQueue = (int)RenderQueue.Transparent + 10 + queueOffset;
                        }
                        material.SetShaderPassEnabled("ShadowCaster", false);
                        material.SetShaderPassEnabled("CharacterShadowCaster", false);
                        material.SetShaderPassEnabled("CharacterClothShadowCaster", false); 
                        break;
                    case 2:
                        material.SetOverrideTag("RenderType", "Transparent");
                        material.SetInt("_SrcBlend", (int)BlendMode.One);
                        material.SetInt("_DstBlend", (int)BlendMode.OneMinusSrcAlpha);
                        material.SetInt("_ZWrite", 0);
                        //material.SetFloat(" _AlphaPremultiply", 1.0f);
                        if (!material.HasProperty("_StandardMode"))
                        {
                            material.EnableKeyword("_ALPHAPREMULTIPLY_ON");
                        }
                        if (isST == false)
                        {
                            if (isTransparentShadowCaster == true)
                            {
                                material.renderQueue = (int)RenderQueue.Transparent + 20;
                            }
                            else
                                material.renderQueue = (int)RenderQueue.Transparent + queueOffset;
                        }
                        else
                        {
                            material.renderQueue = (int)RenderQueue.Transparent + 10 + queueOffset;
                        }
                        if (alphaTest > 0.5f)
                        {
                            material.SetInt("_SrcBlend", (int)BlendMode.SrcAlpha);
                            material.SetInt("_DstBlend", (int)BlendMode.OneMinusSrcAlpha);
                        }

                        material.SetShaderPassEnabled("ShadowCaster", false);
                        material.SetShaderPassEnabled("CharacterShadowCaster", false);
                        material.SetShaderPassEnabled("CharacterClothShadowCaster", false);
                        break;
                    case 3:
                        material.SetOverrideTag("RenderType", "Transparent");
                        material.SetInt("_SrcBlend", (int)BlendMode.SrcAlpha);
                        material.SetInt("_DstBlend", (int)BlendMode.One);
                        material.SetInt("_ZWrite", 0);
                        //material.SetFloat(" _AlphaPremultiply", 0.0f);
                        material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                        if (isST == false)
                        {
                            if (isTransparentShadowCaster == true)
                            {
                                material.renderQueue = (int)RenderQueue.Transparent + 20;
                            }
                            else
                                material.renderQueue = (int)RenderQueue.Transparent + queueOffset;
                        }
                        else
                        {
                            material.renderQueue = (int)RenderQueue.Transparent + 10 + queueOffset;
                        }
                        if (alphaTest > 0.5f)
                        {
                            material.SetInt("_SrcBlend", (int)BlendMode.SrcAlpha);
                            material.SetInt("_DstBlend", (int)BlendMode.OneMinusSrcAlpha);
                        }
                        material.SetShaderPassEnabled("ShadowCaster", false);
                        material.SetShaderPassEnabled("CharacterShadowCaster", false);
                        material.SetShaderPassEnabled("CharacterClothShadowCaster", false);
                        break;
                    case 4:
                        material.SetOverrideTag("RenderType", "Transparent");
                        material.SetInt("_SrcBlend", (int)BlendMode.DstColor);
                        material.SetInt("_DstBlend", (int)BlendMode.Zero);
                        material.SetInt("_ZWrite", 0);
                        //material.SetFloat(" _AlphaPremultiply", 0.0f);
                        material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                        if (isST == false)
                        {
                            if (isTransparentShadowCaster == true)
                            {
                                material.renderQueue = (int)RenderQueue.Transparent + 20;
                            }
                            else
                                material.renderQueue = (int)RenderQueue.Transparent + queueOffset;
                        }
                        else
                        {
                            material.renderQueue = (int)RenderQueue.Transparent + 10 + queueOffset;
                        }
                        if (alphaTest > 0.5f)
                        {
                            material.SetInt("_SrcBlend", (int)BlendMode.SrcAlpha);
                            material.SetInt("_DstBlend", (int)BlendMode.OneMinusSrcAlpha);
                        }
                        material.SetShaderPassEnabled("ShadowCaster", false);
                        material.SetShaderPassEnabled("CharacterShadowCaster", false);
                        material.SetShaderPassEnabled("CharacterClothShadowCaster", false);
                        break;
                }

                int standardMode = 0;
                if (material.HasProperty("_StandardMode"))
                {
                    standardMode = material.GetInt("_StandardMode");
                    switch (standardMode)
                    {
                        case 0:
                            material.SetShaderPassEnabled("StandardPreZ", false);
                            material.SetShaderPassEnabled("ClothStencil", false);
                            //material.SetInt("_ModifiedCullMode", material.GetInt("_CullMode"));
                            //material.SetShaderPassEnabled("ForwardLitBack", false);
                            material.SetShaderPassEnabled("SRPDefaultUnlit", false);
                            material.SetShaderPassEnabled("SpecialTranspPreZ", false);
                            material.SetInt("_ModifiedZTest", 4);
                            break;
                        case 1:
                            material.SetShaderPassEnabled("StandardPreZ", material.GetFloat("_RenderingMode") == 0);
                            material.SetShaderPassEnabled("ClothStencil", false);
                            //material.SetInt("_ModifiedCullMode", material.GetInt("_CullMode"));
                            //material.SetShaderPassEnabled("ForwardLitBack", false);
                            material.SetShaderPassEnabled("SRPDefaultUnlit", false);
                            material.SetShaderPassEnabled("SpecialTranspPreZ", false);
                            material.SetInt("_ModifiedZTest", material.GetFloat("_RenderingMode") == 0 ? 3:4);
                            break;
                        case 2:
                            material.SetShaderPassEnabled("StandardPreZ", false);
                            material.SetShaderPassEnabled("ClothStencil", true);
                            //material.SetInt("_ModifiedCullMode", 2);
                            //material.SetShaderPassEnabled("ForwardLitBack", true);
                            material.SetShaderPassEnabled("SRPDefaultUnlit", false);
                            material.SetShaderPassEnabled("SpecialTranspPreZ", false);
                            material.SetInt("_ModifiedZTest", 4);
                            break;
                        case 3:
                            material.SetShaderPassEnabled("StandardPreZ", material.GetFloat("_RenderingMode") == 0);
                            material.SetShaderPassEnabled("ClothStencil", true);
                            //material.SetInt("_ModifiedCullMode", 2);
                            //material.SetShaderPassEnabled("ForwardLitBack", true);
                            material.SetShaderPassEnabled("SRPDefaultUnlit", false);
                            material.SetShaderPassEnabled("SpecialTranspPreZ", false);
                            material.SetInt("_ModifiedZTest", material.GetFloat("_RenderingMode") == 0 ? 3:4);
                            break;
                        case 4:
                            material.SetShaderPassEnabled("StandardPreZ", false);
                            material.SetShaderPassEnabled("ClothStencil", false);
                            //material.SetInt("_ModifiedCullMode", 2);
                            //material.SetShaderPassEnabled("ForwardLitBack", true);
                            material.SetShaderPassEnabled("SRPDefaultUnlit", false);
                            material.SetShaderPassEnabled("SpecialTranspPreZ", true);
                            material.SetInt("_ModifiedZTest", 4);
                            break;
                        case 5:
                            material.SetShaderPassEnabled("StandardPreZ", false);
                            material.SetShaderPassEnabled("ClothStencil", false);
                            //material.SetInt("_ModifiedCullMode", 2);
                            //material.SetShaderPassEnabled("ForwardLitBack", true);
                            material.SetShaderPassEnabled("SRPDefaultUnlit", true);
                            material.SetShaderPassEnabled("SpecialTranspPreZ", false);
                            material.SetInt("_ModifiedZTest", 4);
                            break;
                    }
                }
            }
        }

        /// <summary>
        ///   <para>Set ShadowCaster based on which Shadowcaster Mode (Transparent or Opaque) is selected.</para>
        /// </summary>
        /// <param name="materials">Arrays of materials of all the object being inspected. Their Render Queue will always be set 3010.</param>
        public static void SetOnFurShellPropChange(UnityEngine.Object[] materials)
        {
            foreach (Material material in materials)
            {
                material.SetOverrideTag("RenderType", "Transparent");
                float casterTransparentShadow = 0;
                int queueOffset = 0;
                if (material.HasProperty("_QueueOffset"))
                    queueOffset = material.GetInt("_QueueOffset");

                if (material.HasProperty("_TransparentShadowCaster"))
                    casterTransparentShadow = material.GetFloat("_TransparentShadowCaster");

                if (casterTransparentShadow != 0)
                {
                    material.SetShaderPassEnabled("ShadowCaster", false);
                    material.renderQueue = (int)RenderQueue.Transparent + 10 + queueOffset;
                }
                else
                {
                    material.SetShaderPassEnabled("ShadowCaster", true);
                    material.renderQueue = (int)RenderQueue.Transparent;
                }

                if(material.HasProperty("_OffsetForceOpen") && material.GetFloat("_OffsetForceOpen") > 0)
                {
                    material.renderQueue = (int)RenderQueue.Transparent + (int)material.GetFloat("_OffSetForceVal");
                }
            }
        }

        public static void SetOtherTranslucentObjectPropChange(UnityEngine.Object[] materials)
        {
            foreach (Material material in materials)
            {
                material.SetOverrideTag("RenderType", "Transparent");
                int queueOffset = 0;
                if (material.HasProperty("_QueueOffset"))
                {
                    queueOffset = material.GetInt("_QueueOffset");
                    material.renderQueue = (int)RenderQueue.Transparent + 10 + queueOffset;
                }
            }
        }

        public static void SetFlagOnEmissionChange(UnityEngine.Object[] materials, bool isEmission)
        {
            foreach (Material material in materials)
            {
                material.globalIlluminationFlags =
                    isEmission
                        ? MaterialGlobalIlluminationFlags.BakedEmissive
                        : MaterialGlobalIlluminationFlags.EmissiveIsBlack;
            }
        }

        public static bool NeedShow(string group, out bool validKeyDisabled)
        {
            validKeyDisabled = false;
            if (group == "" || group == "_")
                return true;
            if (GUIData.group.ContainsKey(group))
            {
                // 一般sub
                return GUIData.group[group];
            }
            //直接是关键字就直接返回
            else if (IsKeyWordAtBeginning(group))
            {
                if (IsIncludeEnabledKeyWord(group, out bool hasValidKeyWord))
                    return true;
                else
                {
                    if (hasValidKeyWord) validKeyDisabled = true;
                    return false;
                }
            }
            else
            {
                // 存在后缀，可能是依据枚举的条件sub
                foreach (var prefix in GUIData.group.Keys)
                {
                    if (group.Contains(prefix))
                    {
                        string suffix = group.Substring(prefix.Length, group.Length - prefix.Length).ToUpperInvariant();
                        if (IsIncludeEnabledKeyWord(suffix, out bool hasValidKeyWord))
                            return GUIData.group[prefix];
                        else
                        {
                            if (hasValidKeyWord) validKeyDisabled = true;
                            return false;
                        }
                    }
                }

                return false;
            }
        }

        /*static GUIContent _iconAdd, _iconEdit;
        public static void RampProperty(MaterialProperty prop, string label, MaterialEditor editor, Gradient gradient, AssetImporter assetImporter, string defaultFileName = "JTRP_RampMap")
        {
            if (_iconAdd == null || _iconEdit == null)
            {
                _iconAdd = EditorGUIUtility.IconContent("d_Toolbar Plus");
                _iconEdit = EditorGUIUtility.IconContent("editicon.sml");
            }

            //Label
            var position = EditorGUILayout.GetControlRect();
            var labelRect = position;
            labelRect.height = EditorGUIUtility.singleLineHeight;
            var space = labelRect.height + 4;
            position.y += space - 3;
            position.height -= space;
            EditorGUI.PrefixLabel(labelRect, new GUIContent(label));

            //Texture object field
            var w = EditorGUIUtility.labelWidth;
            var indentLevel = EditorGUI.indentLevel;
            editor.SetDefaultGUIWidths();
            var buttonRect = MaterialEditor.GetRectAfterLabelWidth(labelRect);
            
            EditorGUIUtility.labelWidth = 0;
            EditorGUI.indentLevel = 0;
            var textureRect = MaterialEditor.GetRectAfterLabelWidth(labelRect);
            textureRect.xMax -= buttonRect.width;
            var newTexture = (Texture)EditorGUI.ObjectField(textureRect, prop.textureValue, typeof(Texture2D), false);
            EditorGUIUtility.labelWidth = w;
            EditorGUI.indentLevel = indentLevel;
            if (newTexture != prop.textureValue)
            {
                prop.textureValue = newTexture;
                assetImporter = null;
            }

            //Preview texture override (larger preview, hides texture name)
            var previewRect = new Rect(textureRect.x + 1, textureRect.y + 1, textureRect.width - 19, textureRect.height - 2);
            if (prop.hasMixedValue)
            {
                EditorGUI.DrawPreviewTexture(previewRect, Texture2D.grayTexture);
                GUI.Label(new Rect(previewRect.x + previewRect.width * 0.5f - 10, previewRect.y, previewRect.width * 0.5f, previewRect.height), "―");
            }
            else if (prop.textureValue != null)
                EditorGUI.DrawPreviewTexture(previewRect, prop.textureValue);

            if (prop.textureValue != null)
            {
                assetImporter = AssetImporter.GetAtPath(AssetDatabase.GetAssetPath(prop.textureValue));
            }

            var buttonRectL = new Rect(buttonRect.x, buttonRect.y, buttonRect.width * 0.5f, buttonRect.height);
            var buttonRectR = new Rect(buttonRectL.xMax, buttonRect.y, buttonRect.width * 0.5f, buttonRect.height);
            bool needCreat = false;
            if (GUI.Button(buttonRectL, _iconEdit))
            {
                if ((assetImporter != null) && (assetImporter.userData.StartsWith("GRADIENT") || assetImporter.userData.StartsWith("gradient:")) && !prop.hasMixedValue)
                {
                    TCP2_RampGenerator.OpenForEditing((Texture2D)prop.textureValue, editor.targets, true, false);
                }
                else
                {
                    needCreat = true;
                }
            }
            if (GUI.Button(buttonRectR, _iconAdd) || needCreat)
            {
                var lastSavePath = GradientManager.LAST_SAVE_PATH;
                if (!lastSavePath.Contains(Application.dataPath))
                    lastSavePath = Application.dataPath;

                var path = EditorUtility.SaveFilePanel("Create New Ramp Texture", lastSavePath, defaultFileName, "png");
                if (!string.IsNullOrEmpty(path))
                {
                    bool overwriteExistingFile = File.Exists(path);

                    GradientManager.LAST_SAVE_PATH = Path.GetDirectoryName(path);

                    //Create texture and save PNG
                    var projectPath = path.Replace(Application.dataPath, "Assets");
                    GradientManager.CreateAndSaveNewGradientTexture(256, projectPath);

                    //Load created texture
                    var texture = AssetDatabase.LoadAssetAtPath<Texture2D>(projectPath);
                    assetImporter = AssetImporter.GetAtPath(projectPath);

                    //Assign to material(s)
                    foreach (var item in prop.targets)
                    {
                        ((Material)item).SetTexture(prop.name, texture);
                    }

                    //Open for editing
                    TCP2_RampGenerator.OpenForEditing(texture, editor.targets, true, !overwriteExistingFile);
                }
            }

        }*/
    }
} //namespace ShaderDrawer