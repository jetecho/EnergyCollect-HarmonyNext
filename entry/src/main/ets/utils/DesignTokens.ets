/**
 * 设计 Token：卡片圆角与内边距统一档位。
 * 对齐 HarmonyOS 设计系统（HDS）官方视觉风格指南「系统通用圆角」5 档
 * （4 / 8 / 12 / 16 / 24vp）与「间隔参数」栅格（4 / 8 / 12 / 16 / 24 / 32vp）。
 *
 * 圆角（vp，官方 token 全量表）：
 *   - CORNER_XS  (4)  标签、角标
 *   - CORNER_SM  (8)  小控件：小按钮、输入框、tooltip
 *   - CORNER_MD  (12) 标准卡片 / 宫格（数据卡片）
 *   - CORNER_LG  (16) 大圆角：通知卡片、弹出框
 *   - CORNER_XXL (24) 超大圆角：底部弹窗、输入框（大容器）
 *
 * 内边距（vp）：
 *   - PAD_CARD (16)            标准内容卡四周内边距（= 手机屏幕边距 / spacing-lg）
 *   - PAD_ROW   {左16右16上12下12}  列表行卡内边距（左右=屏幕边距 16 / 上下=间距 12）
 */

export const CORNER_XS: number = 4;
export const CORNER_SM: number = 8;
export const CORNER_MD: number = 12;
export const CORNER_LG: number = 16;
export const CORNER_XXL: number = 24;

export const PAD_CARD: number = 16;

interface RowPadding {
  left: number;
  right: number;
  top: number;
  bottom: number;
}

export const PAD_ROW: RowPadding = { left: 16, right: 16, top: 12, bottom: 12 };
