using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace JTRP.ShaderDrawer
{
    /// <summary>
    /// 创建一个折叠组
    /// group：折叠组，不提供则使用属性名称（非显示名称）
    /// keyword：_为忽略，不填和__为属性名大写 + _ON
    /// style：0 默认关闭；1 默认打开；2 默认关闭无toggle；3 默认打开无toggle
    /// </summary>
    public class MainDrawer : MaterialPropertyDrawer
    {
        bool show = false;
        string group;
        string keyWord;
        int style;

        public MainDrawer() : this("")
        {
        }

        public MainDrawer(string group) : this(group, "", 0)
        {
        }

        public MainDrawer(string group, string keyword) : this(group, keyword, 0)
        {
        }

        public MainDrawer(string group, string keyWord, float style)
        {
            this.group = group;
            this.keyWord = keyWord;
            this.style = (int)style;
        }

        public override void OnGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            var value = prop.floatValue == 1.0f;
            EditorGUI.showMixedValue = prop.hasMixedValue;
            string g = group != "" ? group : prop.name;
            var lastShow = GUIData.group.ContainsKey(g) ? GUIData.group[g] : true;
            show = ((style == 1 || style == 3) && lastShow) ? true : show;

            bool result = Func.Foldout(ref show, value, style == 0 || style == 1, label.text);
            EditorGUI.showMixedValue = false;

            if (result != value)
            {
                prop.floatValue = result ? 1.0f : 0.0f;
                Func.SetShaderKeyWord(editor.targets, Func.GetKeyWord(keyWord, prop.name), result);
            }
            else // 有时会出现toggle激活key却未激活的情况
            {
                if (!prop.hasMixedValue)
                    Func.SetShaderKeyWord(editor.targets, Func.GetKeyWord(keyWord, prop.name), result);
            }

            if (GUIData.group.ContainsKey(g))
            {
                GUIData.group[g] = show;
            }
            else
            {
                GUIData.group.Add(g, show);
            }
        }
    }

    /// <summary>
    /// 在折叠组内以默认形式绘制属性
    /// group：父折叠组的group key，支持后缀KWEnum或SubToggle的KeyWord以根据enum显示
    /// </summary>
    public class SubDrawer : MaterialPropertyDrawer
    {
        public static readonly int propRight = 80;
        public static readonly int propHeight = 20;
        protected string group = "";
        protected float height;
        protected virtual bool matchPropType => true;
        protected MaterialProperty prop;
        protected MaterialProperty[] props;

        public SubDrawer()
        {
        }

        public SubDrawer(string group)
        {
            this.group = group;
        }

        public override void OnGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            height = position.height;
            this.prop = prop;
            props = Func.GetProperties(editor);
            if (!Func.NeedShow(group, out bool validKeyDisabled))
            {
                //依赖其他KeyWord，导致自己不显示的时候，把自己控制的KeyWord也Disable
                if (validKeyDisabled && this is SubToggleDrawer && prop.floatValue > 0.0f)
                {
                    SubToggleDrawer toggleDrawer = this as SubToggleDrawer;
                    prop.floatValue = 0.0f;
                    string keyWord = toggleDrawer.keyWord;
                    Func.SetShaderKeyWord(editor.targets, keyWord, false);
                    if (GUIData.keyWord.ContainsKey(keyWord))
                    {
                        GUIData.keyWord[keyWord] = false;
                    }
                    else
                    {
                        GUIData.keyWord.Add(keyWord, false);
                    }
                }
                else
                    return;
            }
            Func.SetSupportingCharacter(editor.targets);
            if (group != "" && group != "_" && !Func.IsKeyWordAtBeginning(group))
            {
                EditorGUI.indentLevel++;
                if (matchPropType)
                    DrawProp(position, prop, label, editor);
                else
                {
                    Debug.LogWarning(
                        $"{this.GetType()} does not support this MaterialProperty type:'{prop.type}'!");
                    editor.DefaultShaderProperty(prop, label.text);
                }

                EditorGUI.indentLevel--;
            }
            else
            {
                if (matchPropType)
                    DrawProp(position, prop, label, editor);
                else
                {
                    Debug.LogWarning($"{this.GetType()} does not support this MaterialProperty type:'{prop.type}'!");
                    editor.DefaultShaderProperty(prop, label.text);
                }
            }

            MaterialProperty renderingModeProp = LWGUI.FindProp("_RenderingMode", props);
            if (renderingModeProp != null)
            {
                MaterialProperty transparentShadowCasterProp = LWGUI.FindProp("_TransparentShadowCaster", props);
                bool isTransparentShadowCaster = transparentShadowCasterProp == null
                    ? false
                    : Equals(1, (int)transparentShadowCasterProp.floatValue);
                Func.SetOnRenderingModeChange(editor.targets, (int)renderingModeProp.floatValue,
                    isTransparentShadowCaster);
            }
            else
            {
                MaterialProperty furShellProp = LWGUI.FindProp("_IsFurShell", props);
                if (furShellProp != null)
                {
                    Func.SetOnFurShellPropChange(editor.targets);
                }
                MaterialProperty skinModeProp = LWGUI.FindProp("_SkinMode", props);
                MaterialProperty translucentProp = LWGUI.FindProp("_TranslucentObject", props);

                if (skinModeProp != null)
                    Func.SetOnSkinPropChange(editor.targets, (int)skinModeProp.floatValue);
                else if(translucentProp != null)
                    Func.SetOtherTranslucentObjectPropChange(editor.targets);
            }
        }

        public override float GetPropertyHeight(MaterialProperty prop, string label, MaterialEditor editor)
        {
            return Func.NeedShow(group, out bool validKeyDisabled) ? height : -2;
        }

        // 绘制自定义样式属性
        public virtual void DrawProp(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            editor.DefaultShaderProperty(prop, label.text);
        }
    }

    /// <summary>
    /// n为显示的name，k为对应KeyWord，float值为当前激活的数组index
    /// </summary>
    public class KWEnumDrawer : SubDrawer
    {
        #region

        public KWEnumDrawer(string group, string n1, string k1, float isWideMode)
            : this(group, new string[1] { n1 }, new string[1] { k1 }, isWideMode)
        {
        }

        public KWEnumDrawer(string group, string n1, string k1, string n2, string k2, float isWideMode)
            : this(group, new string[2] { n1, n2 }, new string[2] { k1, k2 }, isWideMode)
        {
        }

        public KWEnumDrawer(string group, string n1, string k1, string n2, string k2, string n3, string k3,
            float isWideMode)
            : this(group, new string[3] { n1, n2, n3 }, new string[3] { k1, k2, k3 }, isWideMode)
        {
        }

        public KWEnumDrawer(string group, string n1, string k1, string n2, string k2, string n3, string k3, string n4,
            string k4, float isWideMode)
            : this(group, new string[4] { n1, n2, n3, n4 }, new string[4] { k1, k2, k3, k4 }, isWideMode)
        {
        }

        public KWEnumDrawer(string group, string n1, string k1, string n2, string k2, string n3, string k3, string n4,
            string k4, string n5, string k5, float isWideMode)
            : this(group, new string[5] { n1, n2, n3, n4, n5 }, new string[5] { k1, k2, k3, k4, k5 }, isWideMode)
        {
        }

        public KWEnumDrawer(string group, string[] names, string[] keyWords, float isWideMode)
        {
            this.group = group;
            this.names = names;
            this.isWideMode = isWideMode > 0.5f;
            for (int i = 0; i < keyWords.Length; i++)
            {
                keyWords[i] = keyWords[i].ToUpperInvariant();
                if (!GUIData.keyWord.ContainsKey(keyWords[i]))
                {
                    GUIData.keyWord.Add(keyWords[i], false);
                }
            }

            this.keyWords = keyWords;
            this.values = new int[keyWords.Length];
            for (int index = 0; index < keyWords.Length; ++index)
                this.values[index] = index;
        }

        #endregion

        protected override bool matchPropType => prop.type == MaterialProperty.PropType.Float;
        protected string[] names, keyWords;
        protected bool isWideMode;
        protected int[] values;

        public override void DrawProp(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            int index = (int)prop.floatValue;

            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = prop.hasMixedValue;
            int num;
            var rect = EditorGUILayout.GetControlRect(true);
            if (isWideMode)
            {
                float oldLabelWidth = EditorGUIUtility.labelWidth;
                EditorGUIUtility.labelWidth = EditorGUIUtility.currentViewWidth - 154f;
                num = EditorGUI.IntPopup(rect, label.text, index, this.names, this.values);
                EditorGUIUtility.labelWidth = oldLabelWidth;
            }
            else
                num = EditorGUI.IntPopup(rect, label.text, index, this.names, this.values);

            EditorGUI.showMixedValue = false;
            if (EditorGUI.EndChangeCheck())
            {
                prop.floatValue = num;
            }

            Func.SetShaderKeyWord(editor.targets, keyWords, num);
        }
    }

    public class SubEnumDrawer : SubDrawer
    {
        #region

        public SubEnumDrawer(string group, string n1, float value1, float isWideMode)
            : this(group, new string[1] { n1 }, new int[1] { (int)value1 }, isWideMode)
        {
        }


        public SubEnumDrawer(string group, string n1, float value1, string n2, float value2, float isWideMode)
            : this(group, new string[2] { n1, n2 }, new int[2] { (int)value1, (int)value2 }, isWideMode)
        {
        }

        public SubEnumDrawer(string group, string n1, float value1, string n2, float value2, string n3, float value3,
            float isWideMode)
            : this(group, new string[3] { n1, n2, n3 }, new int[3] { (int)value1, (int)value2, (int)value3 },
                isWideMode)
        {
        }

        public SubEnumDrawer(string group, string n1, float value1, string n2, float value2, string n3, float value3,
            string n4, float value4, float isWideMode)
            : this(group, new string[4] { n1, n2, n3, n4 },
                new int[4] { (int)value1, (int)value2, (int)value3, (int)value4 }, isWideMode)
        {
        }

        public SubEnumDrawer(string group, string n1, float value1, string n2, float value2, string n3, float value3,
            string n4, float value4, string n5, float value5, float isWideMode)
            : this(group, new string[5] { n1, n2, n3, n4, n5 },
                new int[5] { (int)value1, (int)value2, (int)value3, (int)value4, (int)value5 }, isWideMode)
        {
        }

        public SubEnumDrawer(string group, string n1, float value1, string n2, float value2, string n3, float value3,
            string n4, float value4, string n5, float value5, string n6, float value6, float isWideMode) : this(group,
            new string[6] { n1, n2, n3, n4, n5, n6 },
            new int[6] { (int)value1, (int)value2, (int)value3, (int)value4, (int)value5, (int)value6 }, isWideMode)
        {
        }

        public SubEnumDrawer(string group, string n1, float value1, string n2, float value2, string n3, float value3,
            string n4, float value4, string n5, float value5, string n6, float value6, string n7, float value7,
            float isWideMode)
            : this(group, new string[7] { n1, n2, n3, n4, n5, n6, n7 },
                new int[7]
                {
                    (int)value1, (int)value2, (int)value3, (int)value4, (int)value5, (int)value6, (int)value7
                }, isWideMode)
        {
        }

        public SubEnumDrawer(string group, string n1, float value1, string n2, float value2, string n3, float value3,
            string n4, float value4, string n5, float value5, string n6, float value6, string n7, float value7,
            string n8,
            float value8, float isWideMode) : this(group, new string[8] { n1, n2, n3, n4, n5, n6, n7, n8 },
            new int[8]
            {
                (int)value1, (int)value2, (int)value3, (int)value4, (int)value5, (int)value6, (int)value7, (int)value8
            }, isWideMode)
        {
        }

        public SubEnumDrawer(string group, string n1, float value1, string n2, float value2, string n3, float value3,
            string n4, float value4, string n5, float value5, string n6, float value6, string n7, float value7,
            string n8, float value8, string n9, float value9, float isWideMode)
            : this(group, new string[9] { n1, n2, n3, n4, n5, n6, n7, n8, n9 }, new int[9]
            {
                (int)value1, (int)value2, (int)value3, (int)value4, (int)value5, (int)value6, (int)value7, (int)value8,
                (int)value9
            }, isWideMode)
        {
        }

        public SubEnumDrawer(string group, string n1, float value1, string n2, float value2, string n3, float value3,
            string n4, float value4, string n5, float value5, string n6, float value6, string n7, float value7,
            string n8, float value8, string n9, float value9, string n10, float value10, float isWideMode)
            : this(group, new string[10] { n1, n2, n3, n4, n5, n6, n7, n8, n9, n10 }, new int[10]
            {
                (int)value1, (int)value2, (int)value3, (int)value4, (int)value5, (int)value6, (int)value7, (int)value8,
                (int)value9, (int)value10
            }, isWideMode)
        {
        }

        public SubEnumDrawer(string group, string[] names, int[] values, float isWideMode)
        {
            this.group = group;
            this.names = names;
            this.values = values;
            this.isWideMode = isWideMode > 0.5f;
        }

        #endregion

        protected override bool matchPropType => prop.type == MaterialProperty.PropType.Float;
        protected string[] names;
        protected int[] values;
        protected bool isWideMode;

        public override void DrawProp(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            int index = (int)prop.floatValue;

            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = prop.hasMixedValue;
            int num;
            var rect = EditorGUILayout.GetControlRect(true);
            if (isWideMode)
            {
                float oldLabelWidth = EditorGUIUtility.labelWidth;
                EditorGUIUtility.labelWidth = EditorGUIUtility.currentViewWidth - 154f;
                num = EditorGUI.IntPopup(rect, label.text, index, this.names, this.values);
                EditorGUIUtility.labelWidth = oldLabelWidth;
            }
            else
                num = EditorGUI.IntPopup(rect, label.text, index, this.names, this.values);

            EditorGUI.showMixedValue = false;
            if (EditorGUI.EndChangeCheck())
            {
                prop.floatValue = num;
            }
        }
    }

    /// <summary>
    /// 以单行显示Texture，支持额外属性
    /// group为折叠组title，不填则不加入折叠组
    /// extraPropName为需要显示的额外属性名称
    /// </summary>
    public class TexDrawer : SubDrawer
    {
        public TexDrawer() : this("", "", 0)
        {
        }

        public TexDrawer(string group) : this(group, "", 0)
        {
        }

        public TexDrawer(string group, string extraPropName) : this(group, extraPropName, 0)
        {
        }

        public TexDrawer(string group, string extraPropName, float texOffsetOn)
        {
            this.group = group;
            this.extraPropName = extraPropName;
            this.texOffsetOn = texOffsetOn > 0.5; //贴图偏移
        }


        protected override bool matchPropType => prop.type == MaterialProperty.PropType.Texture;
        string extraPropName;
        bool texOffsetOn;

        public override void DrawProp(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            EditorGUI.ColorField(new Rect(-999, 0, 0, 0), new Color(0, 0, 0, 0));
            var r = EditorGUILayout.GetControlRect();
            MaterialProperty extraProp = null; //主要用来显示ColorTint

            if (extraPropName != "" && extraPropName != "_")
                extraProp = LWGUI.FindProp(extraPropName, props, true);

            if (extraProp != null)
            {
                Rect rect = Rect.zero;
                if (extraProp.type == MaterialProperty.PropType.Range)
                {
                    var w = EditorGUIUtility.labelWidth;
                    EditorGUIUtility.labelWidth = 0;
                    rect = MaterialEditor.GetRectAfterLabelWidth(r);
                    EditorGUIUtility.labelWidth = w;
                }
                else
                    rect = MaterialEditor.GetRectAfterLabelWidth(r);

                editor.TexturePropertyMiniThumbnail(r, prop, label.text, label.tooltip);

                var i = EditorGUI.indentLevel;
                EditorGUI.indentLevel = 0;
                editor.ShaderProperty(rect, extraProp, string.Empty);
                EditorGUI.indentLevel = i;
            }
            else
            {
                EditorGUI.showMixedValue = prop.hasMixedValue;
                editor.TexturePropertyMiniThumbnail(r, prop, label.text, label.tooltip);
            }

            if (texOffsetOn)
            {
                float oldLabelWidth = EditorGUIUtility.labelWidth;
                EditorGUIUtility.labelWidth = EditorGUIUtility.currentViewWidth - 200f;
                editor.TextureScaleOffsetProperty(prop);
                EditorGUIUtility.labelWidth = oldLabelWidth;
            }

            EditorGUI.showMixedValue = false;
        }
    }


    /// <summary>
    /// 将一张4*256的Ramp贴图绘制为Gradient
    /// </summary>
    /*public class RampDrawer : SubDrawer
    {
        public RampDrawer() : this("") { }
        public RampDrawer(string group) : this(group, "JTRP_RampMap") { }

        public RampDrawer(string group, string defaultFileName)
        {
            this.group = group;
            this._defaultFileName = defaultFileName;
        }

        protected override bool matchPropType => prop.type == MaterialProperty.PropType.Texture;
        static GUIContent _iconAdd, _iconEdit;
        Gradient _gradient;
        AssetImporter _assetImporter;
        string _defaultFileName;

        public override void DrawProp(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            Func.RampProperty(prop, prop.displayName, editor, _gradient, _assetImporter, _defaultFileName);
        }
    }*/

    /// <summary>
    /// 支持并排最多4个颜色，支持HSV
    /// !!!注意：更改参数需要手动刷新Drawer实例，在shader中随意输入字符引发报错再撤销以刷新Drawer实例
    /// </summary>
    public class ColorDrawer : SubDrawer
    {
        public ColorDrawer(string group, string parameter) : this(group, parameter, "", "", "")
        {
        }

        public ColorDrawer(string group, string parameter, string color2) : this(group, parameter, color2, "", "")
        {
        }

        public ColorDrawer(string group, string parameter, string color2, string color3) : this(group, parameter,
            color2, color3, "")
        {
        }

        public ColorDrawer(string group, string parameter, string color2, string color3, string color4)
        {
            this.group = group;
            this.parameter = parameter.ToUpperInvariant();
            this.colorStr[0] = color2;
            this.colorStr[1] = color3;
            this.colorStr[2] = color4;
        }

        const string preHSVKeyWord = "_HSV_OTColor";
        protected override bool matchPropType => prop.type == MaterialProperty.PropType.Color;
        bool isHSV => parameter.Contains("HSV");
        bool lastHSV;
        string parameter;
        string[] colorStr = new string[3];

        public override void DrawProp(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            Stack<MaterialProperty> cProps = new Stack<MaterialProperty>();
            for (int i = 0; i < 4; i++)
            {
                if (i == 0)
                {
                    cProps.Push(prop);
                    continue;
                }

                var p = LWGUI.FindProp(colorStr[i - 1], props);
                if (p != null && p.type == MaterialProperty.PropType.Color)
                    cProps.Push(p);
            }

            int count = cProps.Count;

            var rect = EditorGUILayout.GetControlRect();

            var p1 = cProps.Pop();
            EditorGUI.showMixedValue = p1.hasMixedValue;
            editor.ColorProperty(rect, p1, label.text);

            for (int i = 1; i < count; i++)
            {
                var cProp = cProps.Pop();
                EditorGUI.showMixedValue = cProp.hasMixedValue;
                Rect r = new Rect(rect);
                var interval = 13 * i * (-0.25f + EditorGUI.indentLevel * 1.25f);
                float w = propRight * (0.8f + EditorGUI.indentLevel * 0.2f);
                r.xMin += r.width - w * (i + 1) + interval;
                r.xMax -= w * i - interval;

                EditorGUI.BeginChangeCheck();
                Color src, dst;
                if (isHSV)
                    src = Func.HSVToRGB(cProp.colorValue.linear).gamma;
                else
                    src = cProp.colorValue;
                var hdr = (prop.flags & MaterialProperty.PropFlags.HDR) != MaterialProperty.PropFlags.None;
                dst = EditorGUI.ColorField(r, GUIContent.none, src, true, true, hdr);
                if (EditorGUI.EndChangeCheck())
                {
                    if (isHSV)
                        cProp.colorValue = Func.RGBToHSV(dst.linear).gamma;
                    else
                        cProp.colorValue = dst;
                }
            }

            EditorGUI.showMixedValue = false;
            Func.SetShaderKeyWord(editor.targets, preHSVKeyWord, isHSV);
        }
    }

    /// <summary>
    /// 以SubToggle形式显示float，KeyWord行为与内置Toggle一致，
    /// keyword：_为忽略，不填和__为属性名大写 + _ON，将KeyWord后缀于group可根据toggle是否显示
    /// </summary>
    public class SubToggleDrawer : SubDrawer
    {
        public SubToggleDrawer(string group) : this(group, "")
        {
        }

        public SubToggleDrawer(string group, string keyWord)
        {
            this.group = group;
            this.keyWord = keyWord;
        }

        protected override bool matchPropType => prop.type == MaterialProperty.PropType.Float;
        public string keyWord;

        public override void DrawProp(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            EditorGUI.showMixedValue = prop.hasMixedValue;
            EditorGUI.BeginChangeCheck();
            var value = EditorGUILayout.Toggle(label, prop.floatValue > 0.0f);
            string k = Func.GetKeyWord(keyWord, prop.name);
            if (EditorGUI.EndChangeCheck())
            {
                prop.floatValue = value ? 1.0f : 0.0f;
                Func.SetShaderKeyWord(editor.targets, k, value);
            }
            else
            {
                if (!prop.hasMixedValue)
                    Func.SetShaderKeyWord(editor.targets, k, value);
            }

            if (GUIData.keyWord.ContainsKey(k))
            {
                GUIData.keyWord[k] = value;
            }
            else
            {
                GUIData.keyWord.Add(k, value);
            }

            EditorGUI.showMixedValue = false;
        }
    }

    /// <summary>
    /// 同内置PowerSlider
    /// </summary>
    public class SubPowerSliderDrawer : SubDrawer
    {
        public SubPowerSliderDrawer(string group) : this(group, 1)
        {
        }

        public SubPowerSliderDrawer(string group, float power)
        {
            this.group = group;
            this.power = Mathf.Clamp(power, 0, float.MaxValue);
        }

        protected override bool matchPropType => prop.type == MaterialProperty.PropType.Range;
        float power;

        public override void DrawProp(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            EditorGUI.showMixedValue = prop.hasMixedValue;
            Func.PowerSlider(prop, power, EditorGUILayout.GetControlRect(), label);
            EditorGUI.showMixedValue = false;
        }
    }

    /// <summary>
    /// 绘制float以更改Render Queue
    /// </summary>
    public class QueueDrawer : MaterialPropertyDrawer
    {
        public override float GetPropertyHeight(MaterialProperty prop, string label, MaterialEditor editor)
        {
            return 0;
        }

        public override void OnGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            EditorGUI.BeginChangeCheck();
            editor.FloatProperty(prop, label.text);
            int queue = (int)prop.floatValue;
            if (EditorGUI.EndChangeCheck())
            {
                queue = Mathf.Clamp(queue, 1000, 5000);
                prop.floatValue = queue;
                foreach (Material m in editor.targets)
                {
                    m.renderQueue = queue;
                }
            }
        }
    }

    /// <summary>
    /// 与本插件共同使用，在不带Drawer的prop上请使用内置Header，否则会错位，
    /// </summary>
    public class TitleDecorator : SubDrawer
    {
        private readonly string header;
        private readonly float height;

        public TitleDecorator(string group, string header) : this(group, header, 24)
        {
        }

        public TitleDecorator(string group, string header, float height)
        {
            this.group = group;
            this.header = header;
            this.height = height;
        }

        public override void DrawProp(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            GUIStyle s = new GUIStyle(EditorStyles.boldLabel);
            s.fontSize += 1;
            var r = EditorGUILayout.GetControlRect(true, height);
            r.yMin += 5;

            EditorGUI.LabelField(r, new GUIContent(header), s);
        }
    }

    #region 下面是属性定制Drawer，有特殊的用途

    /// <summary>
    /// 绘制RenderingMode,下拉菜单显示会根据主题类型变化
    /// </summary>
    public class RenderingModeDrawer : SubDrawer
    {
        private readonly string[] standardModeNames =
            { "Opaque", "TransparentAlpha", "TransparentPremultiply", "TransparentAdditive", "TransparentMultiply" };

        private readonly int[] standardIntArray = { 0, 1, 2, 3, 4 };

        protected override bool matchPropType => prop.type == MaterialProperty.PropType.Float;

        public RenderingModeDrawer(string group) : base(group)
        {
        }

        public override void DrawProp(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            int oldRenderingMode = (int)prop.floatValue;

            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = prop.hasMixedValue;
            var rect = EditorGUILayout.GetControlRect(true);
            int renderingMode;
            float oldLabelWidth = EditorGUIUtility.labelWidth;
            EditorGUIUtility.labelWidth = EditorGUIUtility.currentViewWidth - 154f;
            renderingMode = EditorGUI.IntPopup(rect, label.text, oldRenderingMode, this.standardModeNames,
                this.standardIntArray);
            EditorGUIUtility.labelWidth = oldLabelWidth;

            EditorGUI.showMixedValue = false;
            if (EditorGUI.EndChangeCheck())
            {
                prop.floatValue = (float)renderingMode;
            }
        }
    }

    public class EmissionDrawer : SubToggleDrawer
    {
        public EmissionDrawer(string group) : base(group)
        {
        }

        public EmissionDrawer(string group, string keyWord) : base(group, keyWord)
        {
        }

        public override void DrawProp(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            EditorGUI.showMixedValue = prop.hasMixedValue;
            EditorGUI.BeginChangeCheck();
            var value = EditorGUILayout.Toggle(label, prop.floatValue > 0.0f);
            string k = Func.GetKeyWord(keyWord, prop.name);
            if (EditorGUI.EndChangeCheck())
            {
                prop.floatValue = value ? 1.0f : 0.0f;
                Func.SetShaderKeyWord(editor.targets, k, value);
                Func.SetFlagOnEmissionChange(editor.targets, value);
            }
            else
            {
                if (!prop.hasMixedValue)
                {
                    Func.SetShaderKeyWord(editor.targets, k, value);
                    Func.SetFlagOnEmissionChange(editor.targets, value);
                }
            }

            if (GUIData.keyWord.ContainsKey(k))
            {
                GUIData.keyWord[k] = value;
            }
            else
            {
                GUIData.keyWord.Add(k, value);
            }

            EditorGUI.showMixedValue = false;
        }
    }

    #endregion
} //namespace ShaderDrawer