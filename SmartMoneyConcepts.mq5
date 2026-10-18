//+------------------------------------------------------------------+
//|                                          SmartMoneyConcepts.mq5  |
//|                Ismaël Ladjohounlou · ladjohounloui@gmail.com     |
//|                          https://github.com/GeneralTradingSarl   |
//+------------------------------------------------------------------+
//| MQL5 port of "Smart Money Concepts" (Pine Script v5).            |
//| Original work © LuxAlgo, licensed under CC BY-NC-SA 4.0          |
//| https://creativecommons.org/licenses/by-nc-sa/4.0/               |
//| This port is a derivative work shared under the same license:    |
//| attribution kept, non-commercial use only, share alike.          |
//+------------------------------------------------------------------+
//| Porting notes (where MetaTrader forces a different mechanism,    |
//| never a different result):                                       |
//| 1. The script runs bar by bar from the oldest bar, exactly like  |
//|    Pine. The forming bar is computed on a copy of the state that |
//|    is thrown away at the next tick (Pine's realtime rollback);   |
//|    only closed bars are committed.                               |
//| 2. label.new / line.new / box.new feed an in-memory collection   |
//|    with Pine's limits (500 of each, oldest deleted first). That  |
//|    collection is then mirrored on the chart.                     |
//| 3. MetaTrader objects have no transparency, so boxes (order      |
//|    blocks, FVG, zones) are painted on a transparent canvas with  |
//|    true alpha blending. Each Pine color.new(c, t) input becomes  |
//|    a color input plus a transparency input.                      |
//| 4. alertcondition() becomes MetaTrader alerts, chosen in the     |
//|    "Alerts" inputs. D, W and M levels use the broker D1, W1, MN1.|
//+------------------------------------------------------------------+
#property copyright   "Ismaël Ladjohounlou · ladjohounloui@gmail.com"
#property link        "https://github.com/GeneralTradingSarl"
#property version     "1.00"
#property description "Smart Money Concepts: internal and swing structure (BOS, CHoCH), order blocks, equal highs and lows, fair value gaps, premium and discount zones, daily, weekly and monthly levels."
#property description " "
#property description "MQL5 port by Ismaël Ladjohounlou of Smart Money Concepts by LuxAlgo, CC BY-NC-SA 4.0 (non-commercial use, same license)."
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   1
#property indicator_label1  "Trend Open;Trend High;Trend Low;Trend Close"
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  C'8,153,129',C'242,54,69'

//---------------------------------------------------------------------------------------------------------------------}
//CONSTANTS & STRINGS & INPUTS
//---------------------------------------------------------------------------------------------------------------------{
#define BULLISH_LEG    1
#define BEARISH_LEG    0
#define BULLISH        1
#define BEARISH       -1
#define GREEN          C'8,153,129'     // #089981
#define RED            C'242,54,69'     // #F23645
#define BLUE           C'33,87,243'     // #2157f3
#define GRAY           C'135,139,148'   // #878b94
#define MONO_BULLISH   C'178,181,190'   // #b2b5be
#define MONO_BEARISH   C'93,96,107'     // #5d606b
#define PINE_BLUE      C'41,98,255'     // color.blue, Pine's default box color

enum ENUM_SMC_MODE
  {
   HISTORICAL,   // Historical
   PRESENT       // Present
  };
enum ENUM_SMC_STYLE
  {
   COLORED,      // Colored
   MONOCHROME    // Monochrome
  };
enum ENUM_SMC_STRUCTURE
  {
   ALL,          // All
   BOS,          // BOS
   CHOCH         // CHoCH
  };
enum ENUM_SMC_SIZE
  {
   TINY,         // Tiny
   SMALL,        // Small
   NORMAL        // Normal
  };
enum ENUM_SMC_OB_FILTER
  {
   ATR,          // Atr
   RANGE         // Cumulative Mean Range
  };
enum ENUM_SMC_MITIGATION
  {
   CLOSE,        // Close
   HIGHLOW       // High/Low
  };
enum ENUM_SMC_LINE
  {
   SOLID,        // ⎯⎯⎯
   DASHED,       // ----
   DOTTED        // ····
  };

input group "Smart Money Concepts"
input ENUM_SMC_MODE       modeInput                        = HISTORICAL;     // Mode
input ENUM_SMC_STYLE      styleInput                       = COLORED;        // Style
input bool                showTrendInput                   = false;          // Color Candles

input group "Real Time Internal Structure"
input bool                showInternalsInput               = true;           // Show Internal Structure
input ENUM_SMC_STRUCTURE  showInternalBullInput            = ALL;            // Bullish Structure
input color               internalBullColorInput           = GREEN;          // Bullish Structure color
input ENUM_SMC_STRUCTURE  showInternalBearInput            = ALL;            // Bearish Structure
input color               internalBearColorInput           = RED;            // Bearish Structure color
input bool                internalFilterConfluenceInput    = false;          // Confluence Filter
input ENUM_SMC_SIZE       internalStructureSize            = TINY;           // Internal Label Size

input group "Real Time Swing Structure"
input bool                showStructureInput               = true;           // Show Swing Structure
input ENUM_SMC_STRUCTURE  showSwingBullInput               = ALL;            // Bullish Structure
input color               swingBullColorInput              = GREEN;          // Bullish Structure color
input ENUM_SMC_STRUCTURE  showSwingBearInput               = ALL;            // Bearish Structure
input color               swingBearColorInput              = RED;            // Bearish Structure color
input ENUM_SMC_SIZE       swingStructureSize               = SMALL;          // Swing Label Size
input bool                showSwingsInput                  = false;          // Show Swings Points
input int                 swingsLengthInput                = 50;             // Swings Points length (min 10)
input bool                showHighLowSwingsInput           = true;           // Show Strong/Weak High/Low

input group "Order Blocks"
input bool                showInternalOrderBlocksInput     = true;           // Internal Order Blocks
input int                 internalOrderBlocksSizeInput     = 5;              // Internal Order Blocks count (1-20)
input bool                showSwingOrderBlocksInput        = false;          // Swing Order Blocks
input int                 swingOrderBlocksSizeInput        = 5;              // Swing Order Blocks count (1-20)
input ENUM_SMC_OB_FILTER  orderBlockFilterInput            = ATR;            // Order Block Filter
input ENUM_SMC_MITIGATION orderBlockMitigationInput        = HIGHLOW;        // Order Block Mitigation
input color               internalBullishOrderBlockColor   = C'49,121,245';  // Internal Bullish OB
input int                 internalBullishOrderBlockTransp  = 80;             // Internal Bullish OB transparency (0-100)
input color               internalBearishOrderBlockColor   = C'247,124,128'; // Internal Bearish OB
input int                 internalBearishOrderBlockTransp  = 80;             // Internal Bearish OB transparency (0-100)
input color               swingBullishOrderBlockColor      = C'24,72,204';   // Bullish OB
input int                 swingBullishOrderBlockTransp     = 80;             // Bullish OB transparency (0-100)
input color               swingBearishOrderBlockColor      = C'178,40,51';   // Bearish OB
input int                 swingBearishOrderBlockTransp     = 80;             // Bearish OB transparency (0-100)

input group "EQH/EQL"
input bool                showEqualHighsLowsInput          = true;           // Equal High/Low
input int                 equalHighsLowsLengthInput        = 3;              // Bars Confirmation
input double              equalHighsLowsThresholdInput     = 0.1;            // Threshold (0-0.5)
input ENUM_SMC_SIZE       equalHighsLowsSizeInput          = TINY;           // Label Size

input group "Fair Value Gaps"
input bool                showFairValueGapsInput           = false;          // Fair Value Gaps
input bool                fairValueGapsThresholdInput      = true;           // Auto Threshold
input ENUM_TIMEFRAMES     fairValueGapsTimeframeInput      = PERIOD_CURRENT; // Timeframe
input color               fairValueGapsBullColorInput      = C'0,255,104';   // Bullish FVG
input int                 fairValueGapsBullTranspInput     = 70;             // Bullish FVG transparency (0-100)
input color               fairValueGapsBearColorInput      = C'255,0,8';     // Bearish FVG
input int                 fairValueGapsBearTranspInput     = 70;             // Bearish FVG transparency (0-100)
input int                 fairValueGapsExtendInput         = 1;              // Extend FVG

input group "Highs & Lows MTF"
input bool                showDailyLevelsInput             = false;          // Daily
input ENUM_SMC_LINE       dailyLevelsStyleInput            = SOLID;          // Daily style
input color               dailyLevelsColorInput            = BLUE;           // Daily color
input bool                showWeeklyLevelsInput            = false;          // Weekly
input ENUM_SMC_LINE       weeklyLevelsStyleInput           = SOLID;          // Weekly style
input color               weeklyLevelsColorInput           = BLUE;           // Weekly color
input bool                showMonthlyLevelsInput           = false;          // Monthly
input ENUM_SMC_LINE       monthlyLevelsStyleInput          = SOLID;          // Monthly style
input color               monthlyLevelsColorInput          = BLUE;           // Monthly color

input group "Premium & Discount Zones"
input bool                showPremiumDiscountZonesInput    = false;          // Premium/Discount Zones
input color               premiumZoneColorInput            = RED;            // Premium Zone
input color               equilibriumZoneColorInput        = GRAY;           // Equilibrium Zone
input color               discountZoneColorInput           = GREEN;          // Discount Zone

input group "Alerts"
input bool                alertInternalBullishBOS          = false;          // Internal Bullish BOS
input bool                alertInternalBullishCHoCH        = false;          // Internal Bullish CHoCH
input bool                alertInternalBearishBOS          = false;          // Internal Bearish BOS
input bool                alertInternalBearishCHoCH        = false;          // Internal Bearish CHoCH
input bool                alertSwingBullishBOS             = false;          // Bullish BOS
input bool                alertSwingBullishCHoCH           = false;          // Bullish CHoCH
input bool                alertSwingBearishBOS             = false;          // Bearish BOS
input bool                alertSwingBearishCHoCH           = false;          // Bearish CHoCH
input bool                alertInternalBullishOB           = false;          // Bullish Internal OB Breakout
input bool                alertInternalBearishOB           = false;          // Bearish Internal OB Breakout
input bool                alertSwingBullishOB              = false;          // Bullish Swing OB Breakout
input bool                alertSwingBearishOB              = false;          // Bearish Swing OB Breakout
input bool                alertEqualHighs                  = false;          // Equal Highs
input bool                alertEqualLows                   = false;          // Equal Lows
input bool                alertBullishFVG                  = false;          // Bullish FVG
input bool                alertBearishFVG                  = false;          // Bearish FVG
input bool                alertOnBarCloseInput             = true;           // Alert on bar close only (else once per bar)
input bool                alertPopupInput                  = true;           // Popup
input bool                alertPushInput                   = false;          // Push notification
input bool                alertMailInput                   = false;          // E-mail

input group "MetaTrader"
input int                 maxBarsInput                     = 0;              // Bars to compute (0 = all bars of the chart)
input string              fontInput                        = "Trebuchet MS"; // Label font

//---------------------------------------------------------------------------------------------------------------------}
//DATA STRUCTURES & VARIABLES
//---------------------------------------------------------------------------------------------------------------------{
#define NA            EMPTY_VALUE      // Pine na for a price
#define NA_INT        INT_MIN          // Pine na for a bar index
#define NA_TIME       LONG_MIN         // Pine na for a time / x coordinate
#define MAX_LABELS    500              // max_labels_count
#define MAX_LINES     500              // max_lines_count
#define MAX_BOXES     500              // max_boxes_count
#define ALERT_COUNT   16

// @type UDT representing alerts as bool fields (indexes of currentAlerts[])
#define INTERNAL_BULLISH_BOS          0
#define INTERNAL_BEARISH_BOS          1
#define INTERNAL_BULLISH_CHOCH        2
#define INTERNAL_BEARISH_CHOCH        3
#define SWING_BULLISH_BOS             4
#define SWING_BEARISH_BOS             5
#define SWING_BULLISH_CHOCH           6
#define SWING_BEARISH_CHOCH           7
#define INTERNAL_BULLISH_ORDER_BLOCK  8
#define INTERNAL_BEARISH_ORDER_BLOCK  9
#define SWING_BULLISH_ORDER_BLOCK    10
#define SWING_BEARISH_ORDER_BLOCK    11
#define EQUAL_HIGHS                  12
#define EQUAL_LOWS                   13
#define BULLISH_FAIR_VALUE_GAP       14
#define BEARISH_FAIR_VALUE_GAP       15

// label styles used by the script
#define LABEL_DOWN    0                // label.style_label_down : text above the point
#define LABEL_UP      1                // label.style_label_up   : text below the point
#define LABEL_LEFT    2                // label.style_label_left : text right of the point

// label texts
enum ENUM_SMC_TEXT
  {
   TX_NONE, TX_BOS, TX_CHOCH, TX_HH, TX_LH, TX_HL, TX_LL, TX_EQH, TX_EQL,
   TX_STRONG_HIGH, TX_WEAK_HIGH, TX_STRONG_LOW, TX_WEAK_LOW,
   TX_PREMIUM, TX_EQUILIBRIUM, TX_DISCOUNT,
   TX_PDH, TX_PDL, TX_PWH, TX_PWL, TX_PMH, TX_PML
  };

// @type UDT representing last swing extremes (top & bottom)
struct trailingExtremes
  {
   double            top;
   double            bottom;
   long              barTime;
   int               barIndex;
   long              lastTopTime;
   long              lastBottomTime;
  };

// @type UDT representing Fair Value Gaps (boxes are drawing ids)
struct fairValueGap
  {
   double            top;
   double            bottom;
   int               bias;
   int               topBox;
   int               bottomBox;
  };

// @type UDT representing Equal Highs Lows display (drawing ids)
struct equalDisplay
  {
   int               l_ine;
   int               l_abel;
  };

// @type UDT representing a pivot point (swing point)
struct pivot
  {
   double            currentLevel;
   double            lastLevel;
   bool              crossed;
   long              barTime;
   int               barIndex;
  };

// @type UDT representing an order block
struct orderBlock
  {
   double            barHigh;
   double            barLow;
   long              barTime;
   int               bias;
  };

// Pine drawing objects. x is a time (xloc.bar_time) or a bar index (xloc.bar_index).
struct PineLabel
  {
   int               id;
   bool              keep;      // `var` object updated for the whole run: exempt from the 500 objects cleanup
   bool              xIsTime;
   long              x;
   double            y;
   int               text;
   color             textColor;
   int               style;
   int               size;
  };
struct PineLine
  {
   int               id;
   bool              keep;
   long              x1;
   double            y1;
   long              x2;
   double            y2;
   color             lineColor;
   int               style;
  };
struct PineBox
  {
   int               id;
   bool              keep;
   long              left;
   double            top;
   long              right;
   double            bottom;
   uint              bgColor;   // ARGB, alpha 0 = color(na)
   uint              borderColor;
   bool              extendRight;
  };

// clamped inputs (Pine minval / maxval) and colors computed once, like the script's `var` colors
int      gSwingsLength, gInternalOBSize, gSwingOBSize, gEqualLength, gFvgExtend;
double   gEqualThreshold;
ENUM_TIMEFRAMES gFvgTimeframe;
bool     gFvgChartTimeframe, gMono;
color    gSwingBullishColor, gSwingBearishColor, gPremiumZoneColor, gDiscountZoneColor;
uint     gFvgBullishColor, gFvgBearishColor;
uint     gInternalBullishOBColor, gInternalBearishOBColor, gSwingBullishOBColor, gSwingBearishOBColor;

// price series, index 0 = oldest bar. Pine bar_index = index - gStart.
datetime gT[];
double   gO[], gH[], gL[], gC[];
// @variable storage for parsed highs / lows
double   gPH[], gPL[];
int      gStart         = 0;    // first computed bar (Pine bar 0)
int      gTotal         = 0;    // bars on the chart
int      gLastIndex     = 0;    // last_bar_index seen by the running execution
datetime gLastTime      = 0;    // last_bar_time seen by the running execution
int      gFirstRealtime = 0;    // first bar computed in real time

//---------------------------------------------------------------------------------------------------------------------}
//ARRAY HELPERS (Pine array.* on value types)
//---------------------------------------------------------------------------------------------------------------------{
template<typename T>
void ArrayPush(T &a[], const T &v)
  {
   int n = ArraySize(a);
   ArrayResize(a, n + 1, 64);
   a[n] = v;
  }
template<typename T>
void ArrayUnshift(T &a[], const T &v)
  {
   int n = ArraySize(a);
   ArrayResize(a, n + 1, 64);
   for(int k = n; k > 0; k--)
      a[k] = a[k - 1];
   a[0] = v;
  }
template<typename T>
void ArrayRemoveAt(T &a[], const int index)
  {
   int n = ArraySize(a);
   for(int k = index; k < n - 1; k++)
      a[k] = a[k + 1];
   ArrayResize(a, n - 1, 64);
  }
template<typename T>
void CopyArray(T &dst[], const T &src[])
  {
   int n = ArraySize(src);
   ArrayResize(dst, n, 64);
   for(int k = 0; k < n; k++)
      dst[k] = src[k];
  }
template<typename T>
void CopyFixed(T &dst[], const T &src[])
  {
   int n = ArraySize(src);
   for(int k = 0; k < n; k++)
      dst[k] = src[k];
  }
template<typename T>
int FindById(const T &a[], const int id)
  {
   int lo = 0, hi = ArraySize(a) - 1;
   while(lo <= hi)
     {
      int m = (lo + hi) >> 1;
      if(a[m].id == id)
         return m;
      if(a[m].id < id)
         lo = m + 1;
      else
         hi = m - 1;
     }
   return -1;
  }
// Pine garbage collection: beyond the limit, the oldest object is deleted
template<typename T>
void Collect(T &a[], const int limit)
  {
   while(ArraySize(a) > limit)
     {
      int k = 0;
      while(k < ArraySize(a) && a[k].keep)
         k++;
      if(k >= ArraySize(a))
         return;
      ArrayRemoveAt(a, k);
     }
  }

// Pine compares floats with an absolute tolerance, measured on TradingView: 1 + 1e-10 > 1 is true,
// 1 + 0.9e-10 > 1 is false, 0.1 + 0.2 == 0.3 is true, at 1, 100 and 1e6 alike.
#define PINE_EPS 1e-10
bool Gt(const double a, const double b) { return a - b > PINE_EPS; }
bool Lt(const double a, const double b) { return b - a > PINE_EPS; }
bool Ge(const double a, const double b) { return !Lt(a, b); }
bool Le(const double a, const double b) { return !Gt(a, b); }
bool Eq(const double a, const double b) { return !Gt(a, b) && !Lt(a, b); }

uint Argb(const color c, const int transparency)
  {
   int t = MathMax(0, MathMin(100, transparency));
   return ColorToARGB(c, (uchar)MathRound(255.0 * (100 - t) / 100.0));
  }

// time - time[1]
long BarDelta(const int i)
  {
   return i > gStart ? (long)gT[i] - (long)gT[i - 1] : NA_TIME;
  }

// array.binary_search_rightmost() on the `times` array (bars gStart..i)
int BinarySearchRightmost(const long value, const int i)
  {
   int lo = gStart, hi = i + 1;           // first index with time > value
   while(lo < hi)
     {
      int m = (lo + hi) >> 1;
      if((long)gT[m] > value)
         hi = m;
      else
         lo = m + 1;
     }
   if(lo > gStart && (long)gT[lo - 1] == value)
      return lo - 1;
   return lo;
  }

//---------------------------------------------------------------------------------------------------------------------}
//SCRIPT STATE (one instance per execution: committed bars, and a throwaway copy for the forming bar)
//---------------------------------------------------------------------------------------------------------------------{
class CSmartMoneyConcepts
  {
public:
   // drawing objects in creation order (id order)
   PineLabel         labels[];
   PineLine          lines[];
   PineBox           boxes[];
   int               nextId;
   // @variable current swing / internal / equal pivots
   pivot             swingHigh, swingLow, internalHigh, internalLow, equalHigh, equalLow;
   // @variable swing / internal trend bias
   int               swingTrend, internalTrend;
   // @variable equal high / low display
   equalDisplay      equalHighDisplay, equalLowDisplay;
   // @variable storage for fairValueGap UDTs
   fairValueGap      fairValueGaps[];
   // @variable last trailing swing high and low
   trailingExtremes  trailing;
   // @variable storage for orderBlock UDTs (swing / internal order blocks) and their boxes
   orderBlock        swingOrderBlocks[], internalOrderBlocks[];
   int               swingOrderBlocksBoxes[], internalOrderBlocksBoxes[];
   // @variable alerts in current bar
   bool              currentAlerts[ALERT_COUNT];
   // series state of ta.atr(200), ta.cum(ta.tr) and the FVG ta.cum()
   double            atrMeasure, atrSum, cumTrueRange, cumFvgDelta;
   int               atrCount;
   // function `var` variables and series history, one slot per Pine call site
   int               legValue[3], legPrevious[3];                 // leg() and ta.change(): swing, internal, equal
   double            crossLevel[4];                               // ta.crossover/crossunder level[1]: internal high, internal low, swing high, swing low
   bool              bullishBar[2], bearishBar[2];                // displayStructure(): internal, swing
   int               structureLine[4], structureLabel[4];         // drawStructure(): internal bull, internal bear, swing bull, swing bear
   bool              structureVar[4];
   int               swingLabel[2];                               // drawLabel(): lows, highs
   int               hlsTopLine, hlsBottomLine, hlsTopLabel, hlsBottomLabel;
   bool              hlsVar;
   int               zoneLabel[3], zoneBox[3];                    // drawZone(): premium, equilibrium, discount
   bool              zoneVar[3];
   int               levelTopLine[3], levelBottomLine[3], levelTopLabel[3], levelBottomLabel[3]; // drawLevels(): D, W, M
   bool              levelVar[3];
   int               candleColorIndex;

   void              Reset(void);
   void              CopyFrom(const CSmartMoneyConcepts &o);
   void              OnBar(const int i, const bool lastConfirmedHistory, const bool isLast);
   void              drawLevels(const int k, const ENUM_TIMEFRAMES tf, const bool sameTimeframe, const ENUM_SMC_LINE style, const color levelColor, const int i);

   // drawing primitives
   int               LabelNew(const bool keep, const bool xIsTime, const long x, const double y, const int text, const color textColor, const int style, const int size);
   void              LabelDelete(const int id);
   void              LabelSetPoint(const int id, const long x, const double y);
   void              LabelSetText(const int id, const int text);
   int               LineNew(const bool keep, const long x1, const double y1, const long x2, const double y2, const color lineColor, const int style);
   void              LineDelete(const int id);
   void              LineSetPoints(const int id, const long x1, const double y1, const long x2, const double y2);
   int               BoxNew(const bool keep, const long left, const double top, const long right, const double bottom, const uint bg, const uint border, const bool extendRight);
   void              BoxDelete(const int id);
   void              BoxSetTopLeft(const int id, const long left, const double top);
   void              BoxSetBottomRight(const int id, const long right, const double bottom);
   void              BoxSetColors(const int id, const uint border, const uint bg);

private:
   void              InitPivot(pivot &p);
   void              UpdateAtr(const double trueRange);
   int               leg(const int i, const int size, const int site);
   void              drawLabel(const int site, const long labelTime, const double labelPrice, const int tag, const color labelColor, const int labelStyle);
   void              drawEqualHighLow(equalDisplay &d, const pivot &p, const double level, const int i, const int size, const bool isEqualHigh);
   void              getCurrentStructure(const int i, const int size, const bool equalHighLow, const bool internal);
   void              newPivotLow(pivot &p, const int i, const int size, const bool equalHighLow, const bool internal);
   void              newPivotHigh(pivot &p, const int i, const int size, const bool equalHighLow, const bool internal);
   void              drawStructure(const int site, const pivot &p, const int tag, const color structureColor, const int lineStyle, const int labelStyle, const int labelSize, const int i);
   void              deleteOrderBlocks(orderBlock &orderBlocks[], const int i, const bool internal);
   void              storeOrdeBlock(const pivot &p, const bool internal, const int bias, const int i);
   void              drawOrderBlocks(const orderBlock &orderBlocks[], const int &b_oxes[], const bool internal);
   void              displayStructure(const int i, const bool internal);
   void              bullishBreak(pivot &p, int &bias, const int i, const bool internal, const bool extraCondition, const color structureColor);
   void              bearishBreak(pivot &p, int &bias, const int i, const bool internal, const bool extraCondition, const color structureColor);
   int               fairValueGapBox(const long leftTime, const long rightTime, const double topPrice, const double bottomPrice, const uint boxColor, const int i);
   void              deleteFairValueGaps(const int i);
   void              drawFairValueGaps(const int i);
   void              updateTrailingExtremes(const int i);
   void              drawHighLowSwings(const int i);
   void              drawZone(const int k, const double labelLevel, const long labelIndex, const double top, const double bottom, const int tag, const color zoneColor, const int style);
   void              drawPremiumDiscountZones(void);
  };

//+------------------------------------------------------------------+
void CSmartMoneyConcepts::InitPivot(pivot &p)
  {
   // pivot.new(na,na,false): barTime = time, barIndex = bar_index of the first bar
   p.currentLevel = NA;
   p.lastLevel    = NA;
   p.crossed      = false;
   p.barTime      = (long)gT[gStart];
   p.barIndex     = gStart;
  }

void CSmartMoneyConcepts::Reset(void)
  {
   ArrayResize(labels, 0, 600);
   ArrayResize(lines, 0, 600);
   ArrayResize(boxes, 0, 600);
   nextId = 0;
   InitPivot(swingHigh);
   InitPivot(swingLow);
   InitPivot(internalHigh);
   InitPivot(internalLow);
   InitPivot(equalHigh);
   InitPivot(equalLow);
   swingTrend    = 0;
   internalTrend = 0;
   equalHighDisplay.l_ine  = -1;
   equalHighDisplay.l_abel = -1;
   equalLowDisplay.l_ine   = -1;
   equalLowDisplay.l_abel  = -1;
   ArrayResize(fairValueGaps, 0, 64);
   trailing.top            = NA;
   trailing.bottom         = NA;
   trailing.barTime        = NA_TIME;
   trailing.barIndex       = NA_INT;
   trailing.lastTopTime    = NA_TIME;
   trailing.lastBottomTime = NA_TIME;
   ArrayResize(swingOrderBlocks, 0, 128);
   ArrayResize(internalOrderBlocks, 0, 128);
   ArrayResize(swingOrderBlocksBoxes, 0, 32);
   ArrayResize(internalOrderBlocksBoxes, 0, 32);
   for(int k = 0; k < ALERT_COUNT; k++)
      currentAlerts[k] = false;
   atrMeasure   = NA;
   atrSum       = 0;
   atrCount     = 0;
   cumTrueRange = 0;
   cumFvgDelta  = 0;
   for(int k = 0; k < 3; k++)
     {
      legValue[k]    = 0;          // var leg = 0
      legPrevious[k] = NA_INT;
      zoneLabel[k]   = -1;
      zoneBox[k]     = -1;
      zoneVar[k]     = false;
      levelTopLine[k] = levelBottomLine[k] = levelTopLabel[k] = levelBottomLabel[k] = -1;
      levelVar[k]    = false;
     }
   for(int k = 0; k < 4; k++)
     {
      crossLevel[k]     = NA;
      structureLine[k]  = -1;
      structureLabel[k] = -1;
      structureVar[k]   = false;
     }
   for(int k = 0; k < 2; k++)
     {
      bullishBar[k] = true;        // var bullishBar = true
      bearishBar[k] = true;
      swingLabel[k] = -1;          // var label l_abel = na
     }
   hlsTopLine = hlsBottomLine = hlsTopLabel = hlsBottomLabel = -1;
   hlsVar = false;
   candleColorIndex = 1;
  }

void CSmartMoneyConcepts::CopyFrom(const CSmartMoneyConcepts &o)
  {
   CopyArray(labels, o.labels);
   CopyArray(lines, o.lines);
   CopyArray(boxes, o.boxes);
   nextId           = o.nextId;
   swingHigh        = o.swingHigh;
   swingLow         = o.swingLow;
   internalHigh     = o.internalHigh;
   internalLow      = o.internalLow;
   equalHigh        = o.equalHigh;
   equalLow         = o.equalLow;
   swingTrend       = o.swingTrend;
   internalTrend    = o.internalTrend;
   equalHighDisplay = o.equalHighDisplay;
   equalLowDisplay  = o.equalLowDisplay;
   CopyArray(fairValueGaps, o.fairValueGaps);
   trailing         = o.trailing;
   CopyArray(swingOrderBlocks, o.swingOrderBlocks);
   CopyArray(internalOrderBlocks, o.internalOrderBlocks);
   CopyArray(swingOrderBlocksBoxes, o.swingOrderBlocksBoxes);
   CopyArray(internalOrderBlocksBoxes, o.internalOrderBlocksBoxes);
   CopyFixed(currentAlerts, o.currentAlerts);
   atrMeasure       = o.atrMeasure;
   atrSum           = o.atrSum;
   cumTrueRange     = o.cumTrueRange;
   cumFvgDelta      = o.cumFvgDelta;
   atrCount         = o.atrCount;
   CopyFixed(legValue, o.legValue);
   CopyFixed(legPrevious, o.legPrevious);
   CopyFixed(crossLevel, o.crossLevel);
   CopyFixed(bullishBar, o.bullishBar);
   CopyFixed(bearishBar, o.bearishBar);
   CopyFixed(structureLine, o.structureLine);
   CopyFixed(structureLabel, o.structureLabel);
   CopyFixed(structureVar, o.structureVar);
   CopyFixed(swingLabel, o.swingLabel);
   hlsTopLine       = o.hlsTopLine;
   hlsBottomLine    = o.hlsBottomLine;
   hlsTopLabel      = o.hlsTopLabel;
   hlsBottomLabel   = o.hlsBottomLabel;
   hlsVar           = o.hlsVar;
   CopyFixed(zoneLabel, o.zoneLabel);
   CopyFixed(zoneBox, o.zoneBox);
   CopyFixed(zoneVar, o.zoneVar);
   CopyFixed(levelTopLine, o.levelTopLine);
   CopyFixed(levelBottomLine, o.levelBottomLine);
   CopyFixed(levelTopLabel, o.levelTopLabel);
   CopyFixed(levelBottomLabel, o.levelBottomLabel);
   CopyFixed(levelVar, o.levelVar);
   candleColorIndex = o.candleColorIndex;
  }

//---------------------------------------------------------------------------------------------------------------------}
//DRAWING PRIMITIVES (label.* / line.* / box.*)
//---------------------------------------------------------------------------------------------------------------------{
int CSmartMoneyConcepts::LabelNew(const bool keep, const bool xIsTime, const long x, const double y, const int text, const color textColor, const int style, const int size)
  {
   PineLabel l;
   l.id        = nextId++;
   l.keep      = keep;
   l.xIsTime   = xIsTime;
   l.x         = x;
   l.y         = y;
   l.text      = text;
   l.textColor = textColor;
   l.style     = style;
   l.size      = size;
   ArrayPush(labels, l);
   Collect(labels, MAX_LABELS);
   return l.id;
  }
void CSmartMoneyConcepts::LabelDelete(const int id)
  {
   int k = id < 0 ? -1 : FindById(labels, id);
   if(k >= 0)
      ArrayRemoveAt(labels, k);
  }
void CSmartMoneyConcepts::LabelSetPoint(const int id, const long x, const double y)
  {
   int k = id < 0 ? -1 : FindById(labels, id);
   if(k < 0)
      return;
   labels[k].x = x;
   labels[k].y = y;
  }
void CSmartMoneyConcepts::LabelSetText(const int id, const int text)
  {
   int k = id < 0 ? -1 : FindById(labels, id);
   if(k >= 0)
      labels[k].text = text;
  }
int CSmartMoneyConcepts::LineNew(const bool keep, const long x1, const double y1, const long x2, const double y2, const color lineColor, const int style)
  {
   PineLine l;
   l.id        = nextId++;
   l.keep      = keep;
   l.x1        = x1;
   l.y1        = y1;
   l.x2        = x2;
   l.y2        = y2;
   l.lineColor = lineColor;
   l.style     = style;
   ArrayPush(lines, l);
   Collect(lines, MAX_LINES);
   return l.id;
  }
void CSmartMoneyConcepts::LineDelete(const int id)
  {
   int k = id < 0 ? -1 : FindById(lines, id);
   if(k >= 0)
      ArrayRemoveAt(lines, k);
  }
void CSmartMoneyConcepts::LineSetPoints(const int id, const long x1, const double y1, const long x2, const double y2)
  {
   int k = id < 0 ? -1 : FindById(lines, id);
   if(k < 0)
      return;
   lines[k].x1 = x1;
   lines[k].y1 = y1;
   lines[k].x2 = x2;
   lines[k].y2 = y2;
  }
int CSmartMoneyConcepts::BoxNew(const bool keep, const long left, const double top, const long right, const double bottom, const uint bg, const uint border, const bool extendRight)
  {
   PineBox b;
   b.id          = nextId++;
   b.keep        = keep;
   b.left        = left;
   b.top         = top;
   b.right       = right;
   b.bottom      = bottom;
   b.bgColor     = bg;
   b.borderColor = border;
   b.extendRight = extendRight;
   ArrayPush(boxes, b);
   Collect(boxes, MAX_BOXES);
   return b.id;
  }
void CSmartMoneyConcepts::BoxDelete(const int id)
  {
   int k = id < 0 ? -1 : FindById(boxes, id);
   if(k >= 0)
      ArrayRemoveAt(boxes, k);
  }
void CSmartMoneyConcepts::BoxSetTopLeft(const int id, const long left, const double top)
  {
   int k = id < 0 ? -1 : FindById(boxes, id);
   if(k < 0)
      return;
   boxes[k].left = left;
   boxes[k].top  = top;
  }
void CSmartMoneyConcepts::BoxSetBottomRight(const int id, const long right, const double bottom)
  {
   int k = id < 0 ? -1 : FindById(boxes, id);
   if(k < 0)
      return;
   boxes[k].right  = right;
   boxes[k].bottom = bottom;
  }
void CSmartMoneyConcepts::BoxSetColors(const int id, const uint border, const uint bg)
  {
   int k = id < 0 ? -1 : FindById(boxes, id);
   if(k < 0)
      return;
   boxes[k].borderColor = border;
   boxes[k].bgColor     = bg;
  }

//---------------------------------------------------------------------------------------------------------------------}
//USER-DEFINED FUNCTIONS
//---------------------------------------------------------------------------------------------------------------------{
// ta.atr(200): RMA of the true range, seeded with the SMA of the first 200 values
void CSmartMoneyConcepts::UpdateAtr(const double trueRange)
  {
   atrCount++;
   if(atrCount < 200)
     {
      atrSum    += trueRange;
      atrMeasure = NA;
     }
   else
      if(atrCount == 200)
        {
         atrSum    += trueRange;
         atrMeasure = atrSum / 200;
        }
      else
        {
         double alpha = 1.0 / 200;
         atrMeasure = alpha * trueRange + (1 - alpha) * atrMeasure;
        }
  }

// @function Get the value of the current leg, it can be 0 (bearish) or 1 (bullish)
// @returns int
int CSmartMoneyConcepts::leg(const int i, const int size, const int site)
  {
   bool newLegHigh = false;
   bool newLegLow  = false;
   int  j          = i - size;
   if(j >= gStart)
     {
      // high[size] > ta.highest(size) / low[size] < ta.lowest(size)
      double highest = gH[i], lowest = gL[i];
      for(int k = i - size + 1; k < i; k++)
        {
         if(gH[k] > highest)
            highest = gH[k];
         if(gL[k] < lowest)
            lowest = gL[k];
        }
      newLegHigh = Gt(gH[j], highest);
      newLegLow  = Lt(gL[j], lowest);
     }
   if(newLegHigh)
      legValue[site] = BEARISH_LEG;
   else
      if(newLegLow)
         legValue[site] = BULLISH_LEG;
   return legValue[site];
  }

// @function create a new label
void CSmartMoneyConcepts::drawLabel(const int site, const long labelTime, const double labelPrice, const int tag, const color labelColor, const int labelStyle)
  {
   if(modeInput == PRESENT)
      LabelDelete(swingLabel[site]);
   swingLabel[site] = LabelNew(false, true, labelTime, labelPrice, tag, labelColor, labelStyle, SMALL);
  }

// @function create a new line and label representing an EQH or EQL
void CSmartMoneyConcepts::drawEqualHighLow(equalDisplay &e_qualDisplay, const pivot &p_ivot, const double level, const int i, const int size, const bool isEqualHigh)
  {
   int   tag        = TX_EQL;
   color equalColor = gSwingBullishColor;
   int   labelStyle = LABEL_UP;
   if(isEqualHigh)
     {
      tag        = TX_EQH;
      equalColor = gSwingBearishColor;
      labelStyle = LABEL_DOWN;
     }
   if(modeInput == PRESENT)
     {
      LineDelete(e_qualDisplay.l_ine);
      LabelDelete(e_qualDisplay.l_abel);
     }
   e_qualDisplay.l_ine = LineNew(false, p_ivot.barTime, p_ivot.currentLevel, (long)gT[i - size], level, equalColor, STYLE_DOT);
   long labelPosition  = (long)MathRound(0.5 * (p_ivot.barIndex + i - size));
   e_qualDisplay.l_abel = LabelNew(false, false, labelPosition, level, tag, equalColor, labelStyle, equalHighsLowsSizeInput);
  }

// @function store current structure and trailing swing points, and also display swing points and equal highs/lows
void CSmartMoneyConcepts::getCurrentStructure(const int i, const int size, const bool equalHighLow, const bool internal)
  {
   int site       = equalHighLow ? 2 : internal ? 1 : 0;
   int currentLeg = leg(i, size, site);
   int previous   = legPrevious[site];
   legPrevious[site] = currentLeg;
   if(previous == NA_INT)            // ta.change() is na on the first bar
      return;
   bool newPivot = currentLeg - previous != 0;
   bool pivotLow = currentLeg - previous == +1;
   if(newPivot)
     {
      if(pivotLow)
        {
         if(equalHighLow)
            newPivotLow(equalLow, i, size, true, false);
         else
            if(internal)
               newPivotLow(internalLow, i, size, false, true);
            else
               newPivotLow(swingLow, i, size, false, false);
        }
      else
        {
         if(equalHighLow)
            newPivotHigh(equalHigh, i, size, true, false);
         else
            if(internal)
               newPivotHigh(internalHigh, i, size, false, true);
            else
               newPivotHigh(swingHigh, i, size, false, false);
        }
     }
  }

void CSmartMoneyConcepts::newPivotLow(pivot &p_ivot, const int i, const int size, const bool equalHighLow, const bool internal)
  {
   double lowSize = gL[i - size];
   if(equalHighLow && p_ivot.currentLevel != NA && atrMeasure != NA && Lt(MathAbs(p_ivot.currentLevel - lowSize), gEqualThreshold * atrMeasure))
     {
      drawEqualHighLow(equalLowDisplay, p_ivot, lowSize, i, size, false);
      currentAlerts[EQUAL_LOWS] = true;
     }
   p_ivot.lastLevel    = p_ivot.currentLevel;
   p_ivot.currentLevel = lowSize;
   p_ivot.crossed      = false;
   p_ivot.barTime      = (long)gT[i - size];
   p_ivot.barIndex     = i - size;
   if(!equalHighLow && !internal)
     {
      trailing.bottom         = p_ivot.currentLevel;
      trailing.barTime        = p_ivot.barTime;
      trailing.barIndex       = p_ivot.barIndex;
      trailing.lastBottomTime = p_ivot.barTime;
     }
   if(showSwingsInput && !internal && !equalHighLow)
     {
      bool lower = p_ivot.lastLevel != NA && Lt(p_ivot.currentLevel, p_ivot.lastLevel);
      drawLabel(0, (long)gT[i - size], p_ivot.currentLevel, lower ? TX_LL : TX_HL, gSwingBullishColor, LABEL_UP);
     }
  }

void CSmartMoneyConcepts::newPivotHigh(pivot &p_ivot, const int i, const int size, const bool equalHighLow, const bool internal)
  {
   double highSize = gH[i - size];
   if(equalHighLow && p_ivot.currentLevel != NA && atrMeasure != NA && Lt(MathAbs(p_ivot.currentLevel - highSize), gEqualThreshold * atrMeasure))
     {
      drawEqualHighLow(equalHighDisplay, p_ivot, highSize, i, size, true);
      currentAlerts[EQUAL_HIGHS] = true;
     }
   p_ivot.lastLevel    = p_ivot.currentLevel;
   p_ivot.currentLevel = highSize;
   p_ivot.crossed      = false;
   p_ivot.barTime      = (long)gT[i - size];
   p_ivot.barIndex     = i - size;
   if(!equalHighLow && !internal)
     {
      trailing.top         = p_ivot.currentLevel;
      trailing.barTime     = p_ivot.barTime;
      trailing.barIndex    = p_ivot.barIndex;
      trailing.lastTopTime = p_ivot.barTime;
     }
   if(showSwingsInput && !internal && !equalHighLow)
     {
      bool higher = p_ivot.lastLevel != NA && Gt(p_ivot.currentLevel, p_ivot.lastLevel);
      drawLabel(1, (long)gT[i - size], p_ivot.currentLevel, higher ? TX_HH : TX_LH, gSwingBearishColor, LABEL_DOWN);
     }
  }

// @function draw line and label representing a structure
void CSmartMoneyConcepts::drawStructure(const int site, const pivot &p_ivot, const int tag, const color structureColor, const int lineStyle, const int labelStyle, const int labelSize, const int i)
  {
   if(!structureVar[site])
     {
      // var line l_ine = line.new(na,na,na,na,xloc = xloc.bar_time) / var label l_abel = label.new(na,na)
      structureLine[site]  = LineNew(false, NA_TIME, NA, NA_TIME, NA, PINE_BLUE, STYLE_SOLID);
      structureLabel[site] = LabelNew(false, false, NA_TIME, NA, TX_NONE, clrBlack, LABEL_DOWN, NORMAL);
      structureVar[site]   = true;
     }
   if(modeInput == PRESENT)
     {
      LineDelete(structureLine[site]);
      LabelDelete(structureLabel[site]);
     }
   structureLine[site]  = LineNew(false, p_ivot.barTime, p_ivot.currentLevel, (long)gT[i], p_ivot.currentLevel, structureColor, lineStyle);
   structureLabel[site] = LabelNew(false, false, (long)MathRound(0.5 * (p_ivot.barIndex + i)), p_ivot.currentLevel, tag, structureColor, labelStyle, labelSize);
  }

// @function delete order blocks
// Pine's for...in re-reads the size each iteration: removing an element skips the next one, as in the original.
void CSmartMoneyConcepts::deleteOrderBlocks(orderBlock &orderBlocks[], const int i, const bool internal)
  {
   // @variable source to use in bearish / bullish order blocks mitigation
   double bearishOrderBlockMitigationSource = orderBlockMitigationInput == CLOSE ? gC[i] : gH[i];
   double bullishOrderBlockMitigationSource = orderBlockMitigationInput == CLOSE ? gC[i] : gL[i];
   for(int index = 0; index < ArraySize(orderBlocks); index++)
     {
      bool crossedOderBlock = false;
      if(Gt(bearishOrderBlockMitigationSource, orderBlocks[index].barHigh) && orderBlocks[index].bias == BEARISH)
        {
         crossedOderBlock = true;
         if(internal)
            currentAlerts[INTERNAL_BEARISH_ORDER_BLOCK] = true;
         else
            currentAlerts[SWING_BEARISH_ORDER_BLOCK]    = true;
        }
      else
         if(Lt(bullishOrderBlockMitigationSource, orderBlocks[index].barLow) && orderBlocks[index].bias == BULLISH)
           {
            crossedOderBlock = true;
            if(internal)
               currentAlerts[INTERNAL_BULLISH_ORDER_BLOCK] = true;
            else
               currentAlerts[SWING_BULLISH_ORDER_BLOCK]    = true;
           }
      if(crossedOderBlock)
         ArrayRemoveAt(orderBlocks, index);
     }
  }

// @function fetch and store order blocks
void CSmartMoneyConcepts::storeOrdeBlock(const pivot &p_ivot, const bool internal, const int bias, const int i)
  {
   if((!internal && showSwingOrderBlocksInput) || (internal && showInternalOrderBlocksInput))
     {
      // parsedHighs.slice(p_ivot.barIndex, bar_index), first index of the max (min for parsedLows)
      int from = p_ivot.barIndex;
      if(from < gStart || from >= i)
         return;
      int parsedIndex = from;
      if(bias == BEARISH)
        {
         double extreme = gPH[from];
         for(int k = from + 1; k < i; k++)
            extreme = MathMax(extreme, gPH[k]);
         while(parsedIndex < i - 1 && !Eq(gPH[parsedIndex], extreme))
            parsedIndex++;
        }
      else
        {
         double extreme = gPL[from];
         for(int k = from + 1; k < i; k++)
            extreme = MathMin(extreme, gPL[k]);
         while(parsedIndex < i - 1 && !Eq(gPL[parsedIndex], extreme))
            parsedIndex++;
        }
      orderBlock o_rderBlock;
      o_rderBlock.barHigh = gPH[parsedIndex];
      o_rderBlock.barLow  = gPL[parsedIndex];
      o_rderBlock.barTime = (long)gT[parsedIndex];
      o_rderBlock.bias    = bias;
      if(internal)
        {
         if(ArraySize(internalOrderBlocks) >= 100)
            ArrayResize(internalOrderBlocks, ArraySize(internalOrderBlocks) - 1);
         ArrayUnshift(internalOrderBlocks, o_rderBlock);
        }
      else
        {
         if(ArraySize(swingOrderBlocks) >= 100)
            ArrayResize(swingOrderBlocks, ArraySize(swingOrderBlocks) - 1);
         ArrayUnshift(swingOrderBlocks, o_rderBlock);
        }
     }
  }

// @function draw order blocks as boxes
void CSmartMoneyConcepts::drawOrderBlocks(const orderBlock &orderBlocks[], const int &b_oxes[], const bool internal)
  {
   int orderBlocksSize = ArraySize(orderBlocks);
   if(orderBlocksSize > 0)
     {
      int maxOrderBlocks = internal ? gInternalOBSize : gSwingOBSize;
      int count          = MathMin(maxOrderBlocks, orderBlocksSize);
      for(int index = 0; index < count && index < ArraySize(b_oxes); index++)
        {
         orderBlock eachOrderBlock = orderBlocks[index];
         uint orderBlockColor = gMono ? (eachOrderBlock.bias == BEARISH ? Argb(MONO_BEARISH, 80) : Argb(MONO_BULLISH, 80))
                                : internal ? (eachOrderBlock.bias == BEARISH ? gInternalBearishOBColor : gInternalBullishOBColor)
                                : (eachOrderBlock.bias == BEARISH ? gSwingBearishOBColor : gSwingBullishOBColor);
         int b_ox = b_oxes[index];
         BoxSetTopLeft(b_ox, eachOrderBlock.barTime, eachOrderBlock.barHigh);
         BoxSetBottomRight(b_ox, (long)gLastTime, eachOrderBlock.barLow);
         BoxSetColors(b_ox, internal ? (uint)0 : orderBlockColor, orderBlockColor);
        }
     }
  }

// @function detect and draw structures, also detect and store order blocks
void CSmartMoneyConcepts::displayStructure(const int i, const bool internal)
  {
   int site = internal ? 0 : 1;
   if(internalFilterConfluenceInput)
     {
      bullishBar[site] = Gt(gH[i] - MathMax(gC[i], gO[i]), MathMin(gC[i], gO[i] - gL[i]));
      bearishBar[site] = Lt(gH[i] - MathMax(gC[i], gO[i]), MathMin(gC[i], gO[i] - gL[i]));
     }
   // a comparison with na is false in Pine, so no internal break before the first swing pivot
   bool  extraCondition = internal ? (internalHigh.currentLevel != NA && swingHigh.currentLevel != NA && !Eq(internalHigh.currentLevel, swingHigh.currentLevel) && bullishBar[site]) : true;
   color bullishColor   = gMono ? MONO_BULLISH : internal ? internalBullColorInput : swingBullColorInput;
   if(internal)
      bullishBreak(internalHigh, internalTrend, i, true, extraCondition, bullishColor);
   else
      bullishBreak(swingHigh, swingTrend, i, false, extraCondition, bullishColor);

   extraCondition     = internal ? (internalLow.currentLevel != NA && swingLow.currentLevel != NA && !Eq(internalLow.currentLevel, swingLow.currentLevel) && bearishBar[site]) : true;
   color bearishColor = gMono ? MONO_BEARISH : internal ? internalBearColorInput : swingBearColorInput;
   if(internal)
      bearishBreak(internalLow, internalTrend, i, true, extraCondition, bearishColor);
   else
      bearishBreak(swingLow, swingTrend, i, false, extraCondition, bearishColor);
  }

void CSmartMoneyConcepts::bullishBreak(pivot &p_ivot, int &t_rend, const int i, const bool internal, const bool extraCondition, const color structureColor)
  {
   // ta.crossover(close, p_ivot.currentLevel)
   int    site     = internal ? 0 : 2;
   double level    = p_ivot.currentLevel;
   double previous = crossLevel[site];
   crossLevel[site] = level;
   bool crossover = i > gStart && level != NA && previous != NA && Gt(gC[i], level) && Le(gC[i - 1], previous);
   if(crossover && !p_ivot.crossed && extraCondition)
     {
      bool choch = t_rend == BEARISH;
      if(internal)
        {
         currentAlerts[INTERNAL_BULLISH_CHOCH] = choch;
         currentAlerts[INTERNAL_BULLISH_BOS]   = !choch;
        }
      else
        {
         currentAlerts[SWING_BULLISH_CHOCH] = choch;
         currentAlerts[SWING_BULLISH_BOS]   = !choch;
        }
      p_ivot.crossed = true;
      t_rend         = BULLISH;
      ENUM_SMC_STRUCTURE show = internal ? showInternalBullInput : showSwingBullInput;
      bool displayCondition = (internal ? showInternalsInput : showStructureInput) && (show == ALL || (show == BOS && !choch) || (show == CHOCH && choch));
      if(displayCondition)
         drawStructure(site, p_ivot, choch ? TX_CHOCH : TX_BOS, structureColor, internal ? STYLE_DASH : STYLE_SOLID, LABEL_DOWN, internal ? internalStructureSize : swingStructureSize, i);
      if((internal && showInternalOrderBlocksInput) || (!internal && showSwingOrderBlocksInput))
         storeOrdeBlock(p_ivot, internal, BULLISH, i);
     }
  }

void CSmartMoneyConcepts::bearishBreak(pivot &p_ivot, int &t_rend, const int i, const bool internal, const bool extraCondition, const color structureColor)
  {
   // ta.crossunder(close, p_ivot.currentLevel)
   int    site     = internal ? 1 : 3;
   double level    = p_ivot.currentLevel;
   double previous = crossLevel[site];
   crossLevel[site] = level;
   bool crossunder = i > gStart && level != NA && previous != NA && Lt(gC[i], level) && Ge(gC[i - 1], previous);
   if(crossunder && !p_ivot.crossed && extraCondition)
     {
      bool choch = t_rend == BULLISH;
      if(internal)
        {
         currentAlerts[INTERNAL_BEARISH_CHOCH] = choch;
         currentAlerts[INTERNAL_BEARISH_BOS]   = !choch;
        }
      else
        {
         currentAlerts[SWING_BEARISH_CHOCH] = choch;
         currentAlerts[SWING_BEARISH_BOS]   = !choch;
        }
      p_ivot.crossed = true;
      t_rend         = BEARISH;
      ENUM_SMC_STRUCTURE show = internal ? showInternalBearInput : showSwingBearInput;
      bool displayCondition = (internal ? showInternalsInput : showStructureInput) && (show == ALL || (show == BOS && !choch) || (show == CHOCH && choch));
      if(displayCondition)
         drawStructure(site, p_ivot, choch ? TX_CHOCH : TX_BOS, structureColor, internal ? STYLE_DASH : STYLE_SOLID, LABEL_UP, internal ? internalStructureSize : swingStructureSize, i);
      if((internal && showInternalOrderBlocksInput) || (!internal && showSwingOrderBlocksInput))
         storeOrdeBlock(p_ivot, internal, BEARISH, i);
     }
  }

// @function draw one fair value gap box (each fair value gap has two boxes)
int CSmartMoneyConcepts::fairValueGapBox(const long leftTime, const long rightTime, const double topPrice, const double bottomPrice, const uint boxColor, const int i)
  {
   long delta = BarDelta(i);
   long right = (rightTime == NA_TIME || delta == NA_TIME) ? NA_TIME : rightTime + gFvgExtend * delta;
   return BoxNew(false, leftTime, topPrice, right, bottomPrice, boxColor, boxColor, false);
  }

// @function delete fair value gaps
void CSmartMoneyConcepts::deleteFairValueGaps(const int i)
  {
   for(int index = 0; index < ArraySize(fairValueGaps); index++)
     {
      fairValueGap eachFairValueGap = fairValueGaps[index];
      if((Lt(gL[i], eachFairValueGap.bottom) && eachFairValueGap.bias == BULLISH) || (Gt(gH[i], eachFairValueGap.top) && eachFairValueGap.bias == BEARISH))
        {
         BoxDelete(eachFairValueGap.topBox);
         BoxDelete(eachFairValueGap.bottomBox);
         ArrayRemoveAt(fairValueGaps, index);
        }
     }
  }

// request.security(syminfo.tickerid, fairValueGapsTimeframeInput, [close[1], open[1], time[1], high[0], low[0], time[0], high[2], low[2]], lookahead = barmerge.lookahead_on)
// and timeframe.change(fairValueGapsTimeframeInput)
void FairValueGapData(const int i, double &lastClose, double &lastOpen, long &lastTime, double &currentHigh, double &currentLow, long &currentTime, double &last2High, double &last2Low, bool &newTimeframe)
  {
   lastClose = lastOpen = currentHigh = currentLow = last2High = last2Low = NA;
   lastTime  = currentTime = NA_TIME;
   newTimeframe = false;
   if(gFvgChartTimeframe)
     {
      currentHigh  = gH[i];
      currentLow   = gL[i];
      currentTime  = (long)gT[i];
      newTimeframe = true;
      if(i - 1 >= gStart)
        {
         lastClose = gC[i - 1];
         lastOpen  = gO[i - 1];
         lastTime  = (long)gT[i - 1];
        }
      if(i - 2 >= gStart)
        {
         last2High = gH[i - 2];
         last2Low  = gL[i - 2];
        }
      return;
     }
   int shift = iBarShift(_Symbol, gFvgTimeframe, gT[i], false);
   if(shift < 0)
      return;
   datetime htfTime = iTime(_Symbol, gFvgTimeframe, shift);
   if(htfTime == 0)
      return;
   currentTime = (long)htfTime;
   if(i >= gFirstRealtime)
     {
      // in real time the higher timeframe bar is only known up to the current chart bar
      currentHigh = gH[i];
      currentLow  = gL[i];
      for(int k = i - 1; k >= gStart && gT[k] >= htfTime; k--)
        {
         currentHigh = MathMax(currentHigh, gH[k]);
         currentLow  = MathMin(currentLow, gL[k]);
        }
     }
   else
     {
      // on history lookahead_on returns the whole higher timeframe bar
      currentHigh = iHigh(_Symbol, gFvgTimeframe, shift);
      currentLow  = iLow(_Symbol, gFvgTimeframe, shift);
     }
   if(iTime(_Symbol, gFvgTimeframe, shift + 1) > 0)
     {
      lastClose = iClose(_Symbol, gFvgTimeframe, shift + 1);
      lastOpen  = iOpen(_Symbol, gFvgTimeframe, shift + 1);
      lastTime  = (long)iTime(_Symbol, gFvgTimeframe, shift + 1);
     }
   if(iTime(_Symbol, gFvgTimeframe, shift + 2) > 0)
     {
      last2High = iHigh(_Symbol, gFvgTimeframe, shift + 2);
      last2Low  = iLow(_Symbol, gFvgTimeframe, shift + 2);
     }
   if(i == gStart)
      newTimeframe = true;
   else
     {
      int previousShift = iBarShift(_Symbol, gFvgTimeframe, gT[i - 1], false);
      newTimeframe = previousShift < 0 || iTime(_Symbol, gFvgTimeframe, previousShift) != htfTime;
     }
  }

// @function draw fair value gaps
void CSmartMoneyConcepts::drawFairValueGaps(const int i)
  {
   double lastClose, lastOpen, currentHigh, currentLow, last2High, last2Low;
   long   lastTime, currentTime;
   bool   newTimeframe;
   FairValueGapData(i, lastClose, lastOpen, lastTime, currentHigh, currentLow, currentTime, last2High, last2Low, newTimeframe);

   double barDeltaPercent = (lastClose == NA || lastOpen == NA) ? NA : (lastClose - lastOpen) / (lastOpen * 100);
   double threshold       = 0;
   if(fairValueGapsThresholdInput)
     {
      // ta.cum(math.abs(newTimeframe ? barDeltaPercent : 0)) / bar_index * 2
      if(newTimeframe && barDeltaPercent != NA)
         cumFvgDelta += MathAbs(barDeltaPercent);
      threshold = i > gStart ? cumFvgDelta / (i - gStart) * 2 : NA;
     }
   bool valid = barDeltaPercent != NA && threshold != NA && currentHigh != NA && currentLow != NA && last2High != NA && last2Low != NA;

   bool bullishFairValueGap = valid && Gt(currentLow, last2High) && Gt(lastClose, last2High) && Gt(barDeltaPercent, threshold) && newTimeframe;
   bool bearishFairValueGap = valid && Lt(currentHigh, last2Low) && Lt(lastClose, last2Low) && Gt(-barDeltaPercent, threshold) && newTimeframe;

   if(bullishFairValueGap)
     {
      currentAlerts[BULLISH_FAIR_VALUE_GAP] = true;
      double middle = (currentLow + last2High) / 2;
      fairValueGap f;
      f.top       = currentLow;
      f.bottom    = last2High;
      f.bias      = BULLISH;
      f.topBox    = fairValueGapBox(lastTime, currentTime, currentLow, middle, gFvgBullishColor, i);
      f.bottomBox = fairValueGapBox(lastTime, currentTime, middle, last2High, gFvgBullishColor, i);
      ArrayUnshift(fairValueGaps, f);
     }
   if(bearishFairValueGap)
     {
      currentAlerts[BEARISH_FAIR_VALUE_GAP] = true;
      double middle = (currentHigh + last2Low) / 2;
      fairValueGap f;
      f.top       = currentHigh;
      f.bottom    = last2Low;
      f.bias      = BEARISH;
      f.topBox    = fairValueGapBox(lastTime, currentTime, currentHigh, middle, gFvgBearishColor, i);
      f.bottomBox = fairValueGapBox(lastTime, currentTime, middle, last2Low, gFvgBearishColor, i);
      ArrayUnshift(fairValueGaps, f);
     }
  }

// @function draw MultiTimeFrame levels
void CSmartMoneyConcepts::drawLevels(const int k, const ENUM_TIMEFRAMES tf, const bool sameTimeframe, const ENUM_SMC_LINE style, const color levelColor, const int i)
  {
   // request.security(syminfo.tickerid, timeframe, [high[1], low[1], time[1], time], lookahead = barmerge.lookahead_on)
   double topLevel = NA, bottomLevel = NA;
   long   leftTime = NA_TIME, rightTime = NA_TIME;
   int    shift    = iBarShift(_Symbol, tf, gT[i], false);
   if(shift >= 0 && iTime(_Symbol, tf, shift) > 0)
     {
      rightTime = (long)iTime(_Symbol, tf, shift);
      if(iTime(_Symbol, tf, shift + 1) > 0)
        {
         topLevel    = iHigh(_Symbol, tf, shift + 1);
         bottomLevel = iLow(_Symbol, tf, shift + 1);
         leftTime    = (long)iTime(_Symbol, tf, shift + 1);
        }
     }
   double parsedTop        = sameTimeframe ? gH[i] : topLevel;
   double parsedBottom     = sameTimeframe ? gL[i] : bottomLevel;
   long   parsedLeftTime   = sameTimeframe ? (long)gT[i] : leftTime;
   long   parsedRightTime  = sameTimeframe ? (long)gT[i] : rightTime;
   long   parsedTopTime    = (long)gT[i];
   long   parsedBottomTime = (long)gT[i];
   if(!sameTimeframe)
     {
      int leftIndex  = parsedLeftTime == NA_TIME ? gStart : BinarySearchRightmost(parsedLeftTime, i);
      int rightIndex = parsedRightTime == NA_TIME ? gStart : BinarySearchRightmost(parsedRightTime, i);
      if(rightIndex > leftIndex)
        {
         double top = gH[leftIndex], bottom = gL[leftIndex];
         for(int n = leftIndex + 1; n < rightIndex; n++)
           {
            top    = MathMax(top, gH[n]);
            bottom = MathMin(bottom, gL[n]);
           }
         int topIndex = leftIndex, bottomIndex = leftIndex;
         while(topIndex < rightIndex - 1 && !Eq(gH[topIndex], top))
            topIndex++;
         while(bottomIndex < rightIndex - 1 && !Eq(gL[bottomIndex], bottom))
            bottomIndex++;
         parsedTopTime    = (long)gT[topIndex];
         parsedBottomTime = (long)gT[bottomIndex];
        }
      else
        {
         parsedTopTime    = (long)gT[gStart];   // initialTime
         parsedBottomTime = (long)gT[gStart];
        }
     }
   if(!levelVar[k])
     {
      int lineStyle = style == SOLID ? STYLE_SOLID : style == DASHED ? STYLE_DASH : STYLE_DOT;
      levelTopLine[k]     = LineNew(true, NA_TIME, NA, NA_TIME, NA, levelColor, lineStyle);
      levelBottomLine[k]  = LineNew(true, NA_TIME, NA, NA_TIME, NA, levelColor, lineStyle);
      levelTopLabel[k]    = LabelNew(true, true, NA_TIME, NA, k == 0 ? TX_PDH : k == 1 ? TX_PWH : TX_PMH, levelColor, LABEL_LEFT, SMALL);
      levelBottomLabel[k] = LabelNew(true, true, NA_TIME, NA, k == 0 ? TX_PDL : k == 1 ? TX_PWL : TX_PML, levelColor, LABEL_LEFT, SMALL);
      levelVar[k]         = true;
     }
   long delta = BarDelta(i);
   long right = delta == NA_TIME ? NA_TIME : (long)gLastTime + 20 * delta;
   LineSetPoints(levelTopLine[k], parsedTopTime, parsedTop, right, parsedTop);
   LabelSetPoint(levelTopLabel[k], right, parsedTop);
   LineSetPoints(levelBottomLine[k], parsedBottomTime, parsedBottom, right, parsedBottom);
   LabelSetPoint(levelBottomLabel[k], right, parsedBottom);
  }

// @function update trailing swing points
void CSmartMoneyConcepts::updateTrailingExtremes(const int i)
  {
   // math.max / math.min return na while the trailing extreme is na
   trailing.top            = trailing.top == NA ? NA : MathMax(gH[i], trailing.top);
   trailing.lastTopTime    = (trailing.top != NA && Eq(trailing.top, gH[i])) ? (long)gT[i] : trailing.lastTopTime;
   trailing.bottom         = trailing.bottom == NA ? NA : MathMin(gL[i], trailing.bottom);
   trailing.lastBottomTime = (trailing.bottom != NA && Eq(trailing.bottom, gL[i])) ? (long)gT[i] : trailing.lastBottomTime;
  }

// @function draw trailing swing points
void CSmartMoneyConcepts::drawHighLowSwings(const int i)
  {
   if(!hlsVar)
     {
      hlsTopLine     = LineNew(true, NA_TIME, NA, NA_TIME, NA, gSwingBearishColor, STYLE_SOLID);
      hlsBottomLine  = LineNew(true, NA_TIME, NA, NA_TIME, NA, gSwingBullishColor, STYLE_SOLID);
      hlsTopLabel    = LabelNew(true, true, NA_TIME, NA, TX_NONE, gSwingBearishColor, LABEL_DOWN, TINY);
      hlsBottomLabel = LabelNew(true, true, NA_TIME, NA, TX_NONE, gSwingBullishColor, LABEL_UP, TINY);
      hlsVar         = true;
     }
   long delta        = BarDelta(i);
   long rightTimeBar = delta == NA_TIME ? NA_TIME : (long)gLastTime + 20 * delta;

   LineSetPoints(hlsTopLine, trailing.lastTopTime, trailing.top, rightTimeBar, trailing.top);
   LabelSetPoint(hlsTopLabel, rightTimeBar, trailing.top);
   LabelSetText(hlsTopLabel, swingTrend == BEARISH ? TX_STRONG_HIGH : TX_WEAK_HIGH);

   LineSetPoints(hlsBottomLine, trailing.lastBottomTime, trailing.bottom, rightTimeBar, trailing.bottom);
   LabelSetPoint(hlsBottomLabel, rightTimeBar, trailing.bottom);
   LabelSetText(hlsBottomLabel, swingTrend == BULLISH ? TX_STRONG_LOW : TX_WEAK_LOW);
  }

// @function draw a zone with a label and a box
void CSmartMoneyConcepts::drawZone(const int k, const double labelLevel, const long labelIndex, const double top, const double bottom, const int tag, const color zoneColor, const int style)
  {
   if(!zoneVar[k])
     {
      zoneLabel[k] = LabelNew(true, false, NA_TIME, NA, tag, zoneColor, style, SMALL);
      zoneBox[k]   = BoxNew(true, NA_TIME, NA, NA_TIME, NA, Argb(zoneColor, 80), 0, false);
      zoneVar[k]   = true;
     }
   BoxSetTopLeft(zoneBox[k], trailing.barTime, top);
   BoxSetBottomRight(zoneBox[k], (long)gLastTime, bottom);
   LabelSetPoint(zoneLabel[k], labelIndex, labelLevel);
  }

// @function draw premium/discount zones
void CSmartMoneyConcepts::drawPremiumDiscountZones(void)
  {
   double top      = trailing.top;
   double bottom   = trailing.bottom;
   bool   both     = top != NA && bottom != NA;
   long   midIndex = trailing.barIndex == NA_INT ? NA_TIME : (long)MathRound(0.5 * (trailing.barIndex + gLastIndex));

   drawZone(0, top, midIndex, top, both ? 0.95 * top + 0.05 * bottom : NA, TX_PREMIUM, gPremiumZoneColor, LABEL_DOWN);

   double equilibriumLevel = both ? (top + bottom) / 2 : NA;
   drawZone(1, equilibriumLevel, gLastIndex, both ? 0.525 * top + 0.475 * bottom : NA, both ? 0.525 * bottom + 0.475 * top : NA, TX_EQUILIBRIUM, equilibriumZoneColorInput, LABEL_LEFT);

   drawZone(2, bottom, midIndex, both ? 0.95 * bottom + 0.05 * top : NA, bottom, TX_DISCOUNT, gDiscountZoneColor, LABEL_UP);
  }

//---------------------------------------------------------------------------------------------------------------------}
//MUTABLE VARIABLES & EXECUTION (one bar)
//---------------------------------------------------------------------------------------------------------------------{
void CSmartMoneyConcepts::OnBar(const int i, const bool lastConfirmedHistory, const bool isLast)
  {
   // @variable alerts in current bar
   for(int k = 0; k < ALERT_COUNT; k++)
      currentAlerts[k] = false;

   // we create the needed boxes for displaying order blocks at the first execution
   if(i == gStart)
     {
      uint blue = Argb(PINE_BLUE, 0);
      if(showSwingOrderBlocksInput)
         for(int index = 1; index <= gSwingOBSize; index++)
           {
            int b_ox = BoxNew(true, NA_TIME, NA, NA_TIME, NA, blue, blue, true);
            ArrayPush(swingOrderBlocksBoxes, b_ox);
           }
      if(showInternalOrderBlocksInput)
         for(int index = 1; index <= gInternalOBSize; index++)
           {
            int b_ox = BoxNew(true, NA_TIME, NA, NA_TIME, NA, blue, blue, true);
            ArrayPush(internalOrderBlocksBoxes, b_ox);
           }
     }

   // @variable default volatility measure
   double trueRange = i > gStart ? MathMax(MathMax(gH[i] - gL[i], MathAbs(gH[i] - gC[i - 1])), MathAbs(gL[i] - gC[i - 1])) : gH[i] - gL[i];
   UpdateAtr(trueRange);
   // @variable parsed volatility measure by user settings
   double volatilityMeasure = atrMeasure;
   if(orderBlockFilterInput == RANGE)
     {
      // ta.cum(ta.tr)/bar_index, ta.tr being na on the first bar
      if(i > gStart)
         cumTrueRange += trueRange;
      volatilityMeasure = i > gStart ? cumTrueRange / (i - gStart) : NA;
     }
   // @variable true if current bar is a high volatility bar
   bool highVolatilityBar = volatilityMeasure != NA && Ge(gH[i] - gL[i], 2 * volatilityMeasure);
   // we store current values into the arrays at each bar
   gPH[i] = highVolatilityBar ? gL[i] : gH[i];
   gPL[i] = highVolatilityBar ? gH[i] : gL[i];

   // plotcandle(): candleColor is read before this bar's structure update
   candleColorIndex = internalTrend == BULLISH ? 0 : 1;

   if(showHighLowSwingsInput || showPremiumDiscountZonesInput)
     {
      updateTrailingExtremes(i);
      if(showHighLowSwingsInput)
         drawHighLowSwings(i);
      if(showPremiumDiscountZonesInput)
         drawPremiumDiscountZones();
     }

   if(showFairValueGapsInput)
      deleteFairValueGaps(i);

   getCurrentStructure(i, gSwingsLength, false, false);
   getCurrentStructure(i, 5, false, true);

   if(showEqualHighsLowsInput)
      getCurrentStructure(i, gEqualLength, true, false);

   if(showInternalsInput || showInternalOrderBlocksInput || showTrendInput)
      displayStructure(i, true);

   if(showStructureInput || showSwingOrderBlocksInput || showHighLowSwingsInput)
      displayStructure(i, false);

   if(showInternalOrderBlocksInput)
      deleteOrderBlocks(internalOrderBlocks, i, true);

   if(showSwingOrderBlocksInput)
      deleteOrderBlocks(swingOrderBlocks, i, false);

   if(showFairValueGapsInput)
      drawFairValueGaps(i);

   if(lastConfirmedHistory || isLast)
     {
      if(showInternalOrderBlocksInput)
         drawOrderBlocks(internalOrderBlocks, internalOrderBlocksBoxes, true);
      if(showSwingOrderBlocksInput)
         drawOrderBlocks(swingOrderBlocks, swingOrderBlocksBoxes, false);
     }
  }

//---------------------------------------------------------------------------------------------------------------------}
//CHART RENDERING
//---------------------------------------------------------------------------------------------------------------------{
CSmartMoneyConcepts committed;   // state after the last closed bar
CSmartMoneyConcepts working;     // committed + the forming bar, rebuilt at every tick

string gPrefix;
string gCanvasName;
string gCanvasRes;
int    gRenderedLabelId[], gRenderedLineId[];
ulong  gRenderedLabelHash[], gRenderedLineHash[];
uint   gPixels[];
int    gCanvasWidth = 0, gCanvasHeight = 0;
ulong  gCanvasHash = 0;
int    gX0 = 0, gPixelsPerBar = 1;

union DoubleBits
  {
   double d;
   ulong  u;
  };
ulong Bits(const double d)
  {
   DoubleBits b;
   b.d = d;
   return b.u;
  }
ulong Mix(const ulong h, const ulong v)
  {
   return (h ^ v) * 1099511628211;
  }

string TextOf(const int code)
  {
   switch(code)
     {
      case TX_BOS:         return "BOS";
      case TX_CHOCH:       return "CHoCH";
      case TX_HH:          return "HH";
      case TX_LH:          return "LH";
      case TX_HL:          return "HL";
      case TX_LL:          return "LL";
      case TX_EQH:         return "EQH";
      case TX_EQL:         return "EQL";
      case TX_STRONG_HIGH: return "Strong High";
      case TX_WEAK_HIGH:   return "Weak High";
      case TX_STRONG_LOW:  return "Strong Low";
      case TX_WEAK_LOW:    return "Weak Low";
      case TX_PREMIUM:     return "Premium";
      case TX_EQUILIBRIUM: return "Equilibrium";
      case TX_DISCOUNT:    return "Discount";
      case TX_PDH:         return "PDH";
      case TX_PDL:         return "PDL";
      case TX_PWH:         return "PWH";
      case TX_PWL:         return "PWL";
      case TX_PMH:         return "PMH";
      case TX_PML:         return "PML";
     }
   return "";
  }

int FontSize(const int size)
  {
   return size == TINY ? 7 : size == SMALL ? 8 : 10;
  }

ENUM_ANCHOR_POINT Anchor(const int style)
  {
   return style == LABEL_DOWN ? ANCHOR_LOWER : style == LABEL_UP ? ANCHOR_UPPER : ANCHOR_LEFT;
  }

// bar index to time, extrapolated beyond the loaded bars
datetime IndexTime(const long index)
  {
   if(index < 0)
      return gT[0] - (datetime)(-index * PeriodSeconds());
   if(index < gTotal)
      return gT[(int)index];
   return gT[gTotal - 1] + (datetime)((index - (gTotal - 1)) * PeriodSeconds());
  }

// TradingView puts a time that falls between two bars (night, weekend) on the next bar
datetime SnapTime(const long t)
  {
   if(t > (long)gT[gTotal - 1])
      return (datetime)t;
   return gT[CeilIndex(t)];
  }

bool LabelVisible(const PineLabel &l)
  {
   return l.x != NA_TIME && l.y != NA;
  }
bool LineVisible(const PineLine &l)
  {
   return l.x1 != NA_TIME && l.x2 != NA_TIME && l.y1 != NA && l.y2 != NA;
  }
bool BoxVisible(const PineBox &b)
  {
   return b.left != NA_TIME && (b.extendRight || b.right != NA_TIME) && b.top != NA && b.bottom != NA;
  }

void DrawLabelObject(const string name, const PineLabel &l, const bool create)
  {
   datetime t = l.xIsTime ? SnapTime(l.x) : IndexTime(l.x);
   if(create)
     {
      ObjectCreate(0, name, OBJ_TEXT, 0, t, l.y);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetString(0, name, OBJPROP_TOOLTIP, "\n");
      ObjectSetString(0, name, OBJPROP_FONT, fontInput);
     }
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, l.y);
   ObjectSetString(0, name, OBJPROP_TEXT, TextOf(l.text));
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize(l.size));
   ObjectSetInteger(0, name, OBJPROP_COLOR, l.textColor);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, Anchor(l.style));
  }

void DrawLineObject(const string name, const PineLine &l, const bool create)
  {
   if(create)
     {
      ObjectCreate(0, name, OBJ_TREND, 0, SnapTime(l.x1), l.y1, SnapTime(l.x2), l.y2);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetString(0, name, OBJPROP_TOOLTIP, "\n");
     }
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, SnapTime(l.x1));
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, l.y1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, SnapTime(l.x2));
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, l.y2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, l.lineColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, l.style);
  }

ulong LabelHash(const PineLabel &l)
  {
   ulong h = 1469598103934665603;
   h = Mix(h, (ulong)(l.xIsTime ? SnapTime(l.x) : IndexTime(l.x)));
   h = Mix(h, Bits(l.y));
   h = Mix(h, (ulong)l.text);
   h = Mix(h, (ulong)l.textColor);
   h = Mix(h, (ulong)(l.style * 16 + l.size * 2 + (l.xIsTime ? 1 : 0)));
   return h;
  }
ulong LineHash(const PineLine &l)
  {
   ulong h = 1469598103934665603;
   h = Mix(h, (ulong)SnapTime(l.x1));
   h = Mix(h, Bits(l.y1));
   h = Mix(h, (ulong)SnapTime(l.x2));
   h = Mix(h, Bits(l.y2));
   h = Mix(h, (ulong)l.lineColor);
   h = Mix(h, (ulong)l.style);
   return h;
  }

// mirror the label collection on the chart: create, update or delete only what changed
bool SyncLabels(const PineLabel &a[])
  {
   int   ids[];
   ulong hashes[];
   ArrayResize(ids, 0, ArraySize(a));
   ArrayResize(hashes, 0, ArraySize(a));
   bool changed = false;
   int  j = 0, rendered = ArraySize(gRenderedLabelId);
   for(int k = 0; k < ArraySize(a); k++)
     {
      if(!LabelVisible(a[k]))
         continue;
      while(j < rendered && gRenderedLabelId[j] < a[k].id)
        {
         ObjectDelete(0, gPrefix + "T" + IntegerToString(gRenderedLabelId[j]));
         changed = true;
         j++;
        }
      ulong h      = LabelHash(a[k]);
      bool  exists = j < rendered && gRenderedLabelId[j] == a[k].id;
      if(!exists || gRenderedLabelHash[j] != h)
        {
         DrawLabelObject(gPrefix + "T" + IntegerToString(a[k].id), a[k], !exists);
         changed = true;
        }
      if(exists)
         j++;
      int n = ArraySize(ids);
      ArrayResize(ids, n + 1);
      ArrayResize(hashes, n + 1);
      ids[n]    = a[k].id;
      hashes[n] = h;
     }
   for(; j < rendered; j++)
     {
      ObjectDelete(0, gPrefix + "T" + IntegerToString(gRenderedLabelId[j]));
      changed = true;
     }
   ArraySwap(gRenderedLabelId, ids);
   ArraySwap(gRenderedLabelHash, hashes);
   return changed;
  }

bool SyncLines(const PineLine &a[])
  {
   int   ids[];
   ulong hashes[];
   ArrayResize(ids, 0, ArraySize(a));
   ArrayResize(hashes, 0, ArraySize(a));
   bool changed = false;
   int  j = 0, rendered = ArraySize(gRenderedLineId);
   for(int k = 0; k < ArraySize(a); k++)
     {
      if(!LineVisible(a[k]))
         continue;
      while(j < rendered && gRenderedLineId[j] < a[k].id)
        {
         ObjectDelete(0, gPrefix + "L" + IntegerToString(gRenderedLineId[j]));
         changed = true;
         j++;
        }
      ulong h      = LineHash(a[k]);
      bool  exists = j < rendered && gRenderedLineId[j] == a[k].id;
      if(!exists || gRenderedLineHash[j] != h)
        {
         DrawLineObject(gPrefix + "L" + IntegerToString(a[k].id), a[k], !exists);
         changed = true;
        }
      if(exists)
         j++;
      int n = ArraySize(ids);
      ArrayResize(ids, n + 1);
      ArrayResize(hashes, n + 1);
      ids[n]    = a[k].id;
      hashes[n] = h;
     }
   for(; j < rendered; j++)
     {
      ObjectDelete(0, gPrefix + "L" + IntegerToString(gRenderedLineId[j]));
      changed = true;
     }
   ArraySwap(gRenderedLineId, ids);
   ArraySwap(gRenderedLineHash, hashes);
   return changed;
  }

// first bar with time >= t (gT is sorted), gTotal when t is after the last bar
int CeilIndex(const long t)
  {
   int lo = 0, hi = gTotal;
   while(lo < hi)
     {
      int m = (lo + hi) >> 1;
      if((long)gT[m] < t)
         lo = m + 1;
      else
         hi = m;
     }
   return lo;
  }

int TimeToX(const long t)
  {
   long lastTime = (long)gT[gTotal - 1];
   if(t >= lastTime)
      return gX0 + (int)MathRound((double)(t - lastTime) / PeriodSeconds() * gPixelsPerBar);
   return gX0 - (gTotal - 1 - CeilIndex(t)) * gPixelsPerBar;
  }

int PriceToY(const double price)
  {
   int x = 0, y = 0;
   ChartTimePriceToXY(0, 0, gT[gTotal - 1], price, x, y);
   return y;
  }

// straight alpha "source over" compositing, the way TradingView stacks translucent boxes
void BlendPixel(const int index, const uint src)
  {
   uint sa = (src >> 24) & 0xFF;
   if(sa == 0)
      return;
   uint dst = gPixels[index];
   uint da  = (dst >> 24) & 0xFF;
   if(da == 0 || sa == 255)
     {
      gPixels[index] = src;
      return;
     }
   uint oa = sa + da * (255 - sa) / 255;
   uint r  = (((src >> 16) & 0xFF) * sa * 255 + ((dst >> 16) & 0xFF) * da * (255 - sa)) / (oa * 255);
   uint g  = (((src >> 8) & 0xFF) * sa * 255 + ((dst >> 8) & 0xFF) * da * (255 - sa)) / (oa * 255);
   uint b  = ((src & 0xFF) * sa * 255 + (dst & 0xFF) * da * (255 - sa)) / (oa * 255);
   gPixels[index] = (oa << 24) | (r << 16) | (g << 8) | b;
  }

void BlendRow(const int y, const int xa, const int xb, const uint src)
  {
   int row = y * gCanvasWidth;
   for(int x = xa; x <= xb; x++)
      BlendPixel(row + x, src);
  }

void PaintBox(const PineBox &b)
  {
   int xa = TimeToX(b.left);
   int xb = b.extendRight ? gCanvasWidth + 1 : TimeToX(b.right);
   if(xa > xb)
     {
      int t = xa;
      xa = xb;
      xb = t;
     }
   int ya = PriceToY(b.top), yb = PriceToY(b.bottom);
   if(ya > yb)
     {
      int t = ya;
      ya = yb;
      yb = t;
     }
   int cxa = MathMax(xa, 0), cxb = MathMin(xb, gCanvasWidth - 1);
   int cya = MathMax(ya, 0), cyb = MathMin(yb, gCanvasHeight - 1);
   if(cxa > cxb || cya > cyb)
      return;
   for(int y = cya; y <= cyb; y++)
      BlendRow(y, cxa, cxb, b.bgColor);
   if(((b.borderColor >> 24) & 0xFF) == 0)
      return;
   if(ya >= 0 && ya < gCanvasHeight)
      BlendRow(ya, cxa, cxb, b.borderColor);
   if(yb != ya && yb >= 0 && yb < gCanvasHeight)
      BlendRow(yb, cxa, cxb, b.borderColor);
   for(int y = MathMax(ya + 1, 0); y <= MathMin(yb - 1, gCanvasHeight - 1); y++)
     {
      if(xa >= 0 && xa < gCanvasWidth)
         BlendPixel(y * gCanvasWidth + xa, b.borderColor);
      if(xb != xa && xb >= 0 && xb < gCanvasWidth)
         BlendPixel(y * gCanvasWidth + xb, b.borderColor);
     }
  }

// boxes are painted on a transparent bitmap behind the candles, redrawn when they or the view change
void RenderBoxes(const PineBox &a[], const bool force)
  {
   if(gTotal < 2)
      return;
   int width  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   if(width <= 0 || height <= 0)
      return;
   int x0, y0, x1, y1;
   if(!ChartTimePriceToXY(0, 0, gT[gTotal - 1], gC[gTotal - 1], x0, y0))
      return;
   int pixelsPerBar = 0;
   if(ChartTimePriceToXY(0, 0, gT[gTotal - 2], gC[gTotal - 2], x1, y1))
      pixelsPerBar = x0 - x1;
   if(pixelsPerBar <= 0)
      pixelsPerBar = 1 << (int)ChartGetInteger(0, CHART_SCALE);

   ulong h = 1469598103934665603;
   h = Mix(h, (ulong)width);
   h = Mix(h, (ulong)height);
   h = Mix(h, (ulong)x0);
   h = Mix(h, (ulong)pixelsPerBar);
   h = Mix(h, Bits(ChartGetDouble(0, CHART_PRICE_MAX)));
   h = Mix(h, Bits(ChartGetDouble(0, CHART_PRICE_MIN)));
   for(int k = 0; k < ArraySize(a); k++)
     {
      if(!BoxVisible(a[k]))
         continue;
      h = Mix(h, (ulong)a[k].id);
      h = Mix(h, (ulong)a[k].left);
      h = Mix(h, (ulong)a[k].right);
      h = Mix(h, Bits(a[k].top));
      h = Mix(h, Bits(a[k].bottom));
      h = Mix(h, (ulong)a[k].bgColor);
      h = Mix(h, (ulong)a[k].borderColor);
     }
   if(!force && h == gCanvasHash && ObjectFind(0, gCanvasName) >= 0)
      return;

   if(ObjectFind(0, gCanvasName) < 0)
     {
      ObjectCreate(0, gCanvasName, OBJ_BITMAP_LABEL, 0, 0, 0);
      ObjectSetInteger(0, gCanvasName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, gCanvasName, OBJPROP_XDISTANCE, 0);
      ObjectSetInteger(0, gCanvasName, OBJPROP_YDISTANCE, 0);
      ObjectSetInteger(0, gCanvasName, OBJPROP_BACK, true);
      ObjectSetInteger(0, gCanvasName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, gCanvasName, OBJPROP_HIDDEN, true);
      ObjectSetString(0, gCanvasName, OBJPROP_TOOLTIP, "\n");
      gCanvasWidth = gCanvasHeight = 0;
     }
   if(width != gCanvasWidth || height != gCanvasHeight)
     {
      gCanvasWidth  = width;
      gCanvasHeight = height;
      ArrayResize(gPixels, width * height);
      ObjectSetInteger(0, gCanvasName, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, gCanvasName, OBJPROP_YSIZE, height);
     }
   gX0           = x0;
   gPixelsPerBar = pixelsPerBar;
   ArrayInitialize(gPixels, 0);
   for(int k = 0; k < ArraySize(a); k++)
      if(BoxVisible(a[k]))
         PaintBox(a[k]);
   if(!ResourceCreate(gCanvasRes, gPixels, gCanvasWidth, gCanvasHeight, 0, 0, gCanvasWidth, COLOR_FORMAT_ARGB_NORMALIZE))
      return;
   ObjectSetString(0, gCanvasName, OBJPROP_BMPFILE, 0, gCanvasRes);
   gCanvasHash = h;
   ChartRedraw(0);
  }

void Render(void)
  {
   bool changed = SyncLines(working.lines);
   changed = SyncLabels(working.labels) || changed;
   RenderBoxes(working.boxes, false);
   if(changed)
      ChartRedraw(0);
  }

void ClearChart(void)
  {
   ObjectsDeleteAll(0, gPrefix);
   ArrayResize(gRenderedLabelId, 0);
   ArrayResize(gRenderedLabelHash, 0);
   ArrayResize(gRenderedLineId, 0);
   ArrayResize(gRenderedLineHash, 0);
   gCanvasHash   = 0;
   gCanvasWidth  = 0;
   gCanvasHeight = 0;
  }

//---------------------------------------------------------------------------------------------------------------------}
//ALERTS
//---------------------------------------------------------------------------------------------------------------------{
string gAlertTitle[ALERT_COUNT] =
  {
   "Internal Bullish BOS", "Internal Bearish BOS", "Internal Bullish CHoCH", "Internal Bearish CHoCH",
   "Bullish BOS", "Bearish BOS", "Bullish CHoCH", "Bearish CHoCH",
   "Bullish Internal OB Breakout", "Bearish Internal OB Breakout", "Bullish Swing OB Breakout", "Bearish Swing OB Breakout",
   "Equal Highs", "Equal Lows", "Bullish FVG", "Bearish FVG"
  };
string gAlertMessage[ALERT_COUNT] =
  {
   "Internal Bullish BOS formed", "Internal Bearish BOS formed", "Internal Bullish CHoCH formed", "Internal Bearish CHoCH formed",
   "Internal Bullish BOS formed", "Bearish BOS formed", "Internal Bullish CHoCH formed", "Bearish CHoCH formed",
   "Price broke bullish internal OB", "Price broke bearish internal OB", "Price broke bullish swing OB", "Price broke bearish swing OB",
   "Equal highs detected", "Equal lows detected", "Bullish FVG formed", "Bearish FVG formed"
  };
int gAlertBar[ALERT_COUNT];

bool AlertEnabled(const int k)
  {
   switch(k)
     {
      case INTERNAL_BULLISH_BOS:         return alertInternalBullishBOS;
      case INTERNAL_BEARISH_BOS:         return alertInternalBearishBOS;
      case INTERNAL_BULLISH_CHOCH:       return alertInternalBullishCHoCH;
      case INTERNAL_BEARISH_CHOCH:       return alertInternalBearishCHoCH;
      case SWING_BULLISH_BOS:            return alertSwingBullishBOS;
      case SWING_BEARISH_BOS:            return alertSwingBearishBOS;
      case SWING_BULLISH_CHOCH:          return alertSwingBullishCHoCH;
      case SWING_BEARISH_CHOCH:          return alertSwingBearishCHoCH;
      case INTERNAL_BULLISH_ORDER_BLOCK: return alertInternalBullishOB;
      case INTERNAL_BEARISH_ORDER_BLOCK: return alertInternalBearishOB;
      case SWING_BULLISH_ORDER_BLOCK:    return alertSwingBullishOB;
      case SWING_BEARISH_ORDER_BLOCK:    return alertSwingBearishOB;
      case EQUAL_HIGHS:                  return alertEqualHighs;
      case EQUAL_LOWS:                   return alertEqualLows;
      case BULLISH_FAIR_VALUE_GAP:       return alertBullishFVG;
      case BEARISH_FAIR_VALUE_GAP:       return alertBearishFVG;
     }
   return false;
  }

void FireAlerts(const bool &flags[], const int i)
  {
   for(int k = 0; k < ALERT_COUNT; k++)
     {
      if(!flags[k] || !AlertEnabled(k) || gAlertBar[k] == i)
         continue;
      gAlertBar[k] = i;
      string text = StringFormat("%s, %s | %s | %s", _Symbol, StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period), 7), gAlertTitle[k], gAlertMessage[k]);
      if(alertPopupInput)
         Alert(text);
      if(alertPushInput)
         SendNotification(text);
      if(alertMailInput)
         SendMail(gAlertTitle[k], text);
     }
  }

//---------------------------------------------------------------------------------------------------------------------}
//EXECUTION DRIVER
//---------------------------------------------------------------------------------------------------------------------{
double bufferOpen[], bufferHigh[], bufferLow[], bufferClose[], bufferColor[];
int    gLastCommitted = -1;   // last closed bar already committed
int    gLevelsBar     = -1;   // varip currentBarIndex of the MTF levels
bool   gNeedFull      = true;
bool   gWaitingData   = false;  // another timeframe's history is still loading
uint   gWaitStart     = 0;

bool HigherTimeframe(const ENUM_TIMEFRAMES tf)
  {
   return PeriodSeconds(_Period) > PeriodSeconds(tf);
  }

bool SeriesReady(const ENUM_TIMEFRAMES tf)
  {
   if(tf == _Period)
      return true;
   // CopyTime() is what asks the terminal to load the other timeframe: it must be called every time
   datetime t[];
   return CopyTime(_Symbol, tf, 0, 1, t) == 1;
  }

bool DataReady(void)
  {
   bool ready = true;
   if(showFairValueGapsInput && !gFvgChartTimeframe)
      ready = SeriesReady(gFvgTimeframe) && ready;
   if(showDailyLevelsInput && !HigherTimeframe(PERIOD_D1))
      ready = SeriesReady(PERIOD_D1) && ready;
   if(showWeeklyLevelsInput && !HigherTimeframe(PERIOD_W1))
      ready = SeriesReady(PERIOD_W1) && ready;
   if(showMonthlyLevelsInput && !HigherTimeframe(PERIOD_MN1))
      ready = SeriesReady(PERIOD_MN1) && ready;
   return ready;
  }

// if barstate.islastconfirmedhistory or (barstate.isrealtime and newBar): levels are kept, never rolled back
void ApplyLevels(const int i)
  {
   if(showDailyLevelsInput && !HigherTimeframe(PERIOD_D1))
      committed.drawLevels(0, PERIOD_D1, _Period == PERIOD_D1, dailyLevelsStyleInput, dailyLevelsColorInput, i);
   if(showWeeklyLevelsInput && !HigherTimeframe(PERIOD_W1))
      committed.drawLevels(1, PERIOD_W1, _Period == PERIOD_W1, weeklyLevelsStyleInput, weeklyLevelsColorInput, i);
   if(showMonthlyLevelsInput && !HigherTimeframe(PERIOD_MN1))
      committed.drawLevels(2, PERIOD_MN1, _Period == PERIOD_MN1, monthlyLevelsStyleInput, monthlyLevelsColorInput, i);
  }

void WriteCandle(const int i, const int colorIndex)
  {
   if(showTrendInput)
     {
      bufferOpen[i]  = gO[i];
      bufferHigh[i]  = gH[i];
      bufferLow[i]   = gL[i];
      bufferClose[i] = gC[i];
      bufferColor[i] = colorIndex;
     }
   else
     {
      bufferOpen[i] = bufferHigh[i] = bufferLow[i] = bufferClose[i] = EMPTY_VALUE;
      bufferColor[i] = 0;
     }
  }

int OnInit()
  {
   gSwingsLength   = MathMax(10, swingsLengthInput);
   gInternalOBSize = MathMax(1, MathMin(20, internalOrderBlocksSizeInput));
   gSwingOBSize    = MathMax(1, MathMin(20, swingOrderBlocksSizeInput));
   gEqualLength    = MathMax(1, equalHighsLowsLengthInput);
   gEqualThreshold = MathMax(0.0, MathMin(0.5, equalHighsLowsThresholdInput));
   gFvgExtend      = MathMax(0, fairValueGapsExtendInput);
   gFvgTimeframe   = fairValueGapsTimeframeInput == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : fairValueGapsTimeframeInput;
   gFvgChartTimeframe = PeriodSeconds(gFvgTimeframe) <= PeriodSeconds(_Period);

   gMono                   = styleInput == MONOCHROME;
   gSwingBullishColor      = gMono ? MONO_BULLISH : swingBullColorInput;
   gSwingBearishColor      = gMono ? MONO_BEARISH : swingBearColorInput;
   gFvgBullishColor        = gMono ? Argb(MONO_BULLISH, 70) : Argb(fairValueGapsBullColorInput, fairValueGapsBullTranspInput);
   gFvgBearishColor        = gMono ? Argb(MONO_BEARISH, 70) : Argb(fairValueGapsBearColorInput, fairValueGapsBearTranspInput);
   gPremiumZoneColor       = gMono ? MONO_BEARISH : premiumZoneColorInput;
   gDiscountZoneColor      = gMono ? MONO_BULLISH : discountZoneColorInput;
   gInternalBullishOBColor = Argb(internalBullishOrderBlockColor, internalBullishOrderBlockTransp);
   gInternalBearishOBColor = Argb(internalBearishOrderBlockColor, internalBearishOrderBlockTransp);
   gSwingBullishOBColor    = Argb(swingBullishOrderBlockColor, swingBullishOrderBlockTransp);
   gSwingBearishOBColor    = Argb(swingBearishOrderBlockColor, swingBearishOrderBlockTransp);

   SetIndexBuffer(0, bufferOpen, INDICATOR_DATA);
   SetIndexBuffer(1, bufferHigh, INDICATOR_DATA);
   SetIndexBuffer(2, bufferLow, INDICATOR_DATA);
   SetIndexBuffer(3, bufferClose, INDICATOR_DATA);
   SetIndexBuffer(4, bufferColor, INDICATOR_COLOR_INDEX);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 2);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, gSwingBullishColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, gSwingBearishColor);
   if(!showTrendInput)
     {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(0, PLOT_SHOW_DATA, false);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, "Smart Money Concepts [Ismaël Ladjohounlou]");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   gPrefix     = "SMC_IL_";
   gCanvasName = gPrefix + "BOXES";
   gCanvasRes  = "::" + gPrefix + "BOXES";
   for(int k = 0; k < ALERT_COUNT; k++)
      gAlertBar[k] = -1;
   gNeedFull = true;
   DataReady();                       // starts loading the other timeframes
   EventSetTimer(1);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, gPrefix);
   ResourceFree(gCanvasRes);
   ChartRedraw(0);
  }

void OnTimer()
  {
   if(gWaitingData)
     {
      // another timeframe's history was missing: recalculate once it is there, or after 10 s without it
      // (no tick may come to call OnCalculate again, on a closed market for instance)
      bool ready = DataReady();
      if(ready || (gNeedFull && GetTickCount() - gWaitStart >= 10000))
        {
         gWaitingData = !ready;
         gNeedFull    = true;
         ChartSetSymbolPeriod(0, _Symbol, _Period);
        }
      return;
     }
   if(gNeedFull)
      return;
   RenderBoxes(working.boxes, false);
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_CHART_CHANGE && !gNeedFull)
      RenderBoxes(working.boxes, false);
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total < 3)
      return 0;
   if(!DataReady())
     {
      if(!gWaitingData)
        {
         gWaitingData = true;
         gWaitStart   = GetTickCount();
        }
      // give the terminal a few seconds to load it, then draw everything else and recalculate once it is there
      if(GetTickCount() - gWaitStart < 10000)
        {
         gNeedFull = true;
         return 0;
        }
     }
   else
      gWaitingData = false;

   bool full = gNeedFull || prev_calculated == 0 || rates_total < gTotal || gLastCommitted < 0
               || gLastCommitted >= rates_total || gT[gLastCommitted] != time[gLastCommitted];
   int  from = full ? 0 : gLastCommitted;
   ArrayResize(gT, rates_total, 1024);
   ArrayResize(gO, rates_total, 1024);
   ArrayResize(gH, rates_total, 1024);
   ArrayResize(gL, rates_total, 1024);
   ArrayResize(gC, rates_total, 1024);
   ArrayResize(gPH, rates_total, 1024);
   ArrayResize(gPL, rates_total, 1024);
   ArrayCopy(gT, time, from, from, rates_total - from);
   ArrayCopy(gO, open, from, from, rates_total - from);
   ArrayCopy(gH, high, from, from, rates_total - from);
   ArrayCopy(gL, low, from, from, rates_total - from);
   ArrayCopy(gC, close, from, from, rates_total - from);
   gTotal = rates_total;

   if(full)
     {
      ClearChart();
      gStart = (maxBarsInput > 0 && rates_total > maxBarsInput) ? rates_total - maxBarsInput : 0;
      if(rates_total - gStart < 3)
         return 0;
      for(int k = 0; k < rates_total; k++)
        {
         bufferOpen[k] = bufferHigh[k] = bufferLow[k] = bufferClose[k] = EMPTY_VALUE;
         bufferColor[k] = 0;
        }
      // history: every closed bar, last_bar_time being the last bar of the chart
      gFirstRealtime = rates_total - 1;
      gLastIndex     = rates_total - 1;
      gLastTime      = gT[rates_total - 1];
      committed.Reset();
      int lastHistory = rates_total - 2;
      for(int i = gStart; i <= lastHistory; i++)
        {
         committed.OnBar(i, i == lastHistory, false);
         WriteCandle(i, committed.candleColorIndex);
        }
      ApplyLevels(lastHistory);
      gLevelsBar     = lastHistory;
      gLastCommitted = lastHistory;
      gNeedFull      = false;
     }
   else
     {
      // bars that just closed: their last tick is committed, as in Pine
      for(int i = gLastCommitted + 1; i <= rates_total - 2; i++)
        {
         gLastIndex = i;
         gLastTime  = gT[i];
         committed.OnBar(i, false, true);
         WriteCandle(i, committed.candleColorIndex);
         if(alertOnBarCloseInput)
            FireAlerts(committed.currentAlerts, i);
        }
      gLastCommitted = rates_total - 2;
     }

   // forming bar: computed on a copy of the committed state, discarded at the next tick (Pine rollback)
   int forming = rates_total - 1;
   gLastIndex  = forming;
   gLastTime   = gT[forming];
   if(forming > gLevelsBar)
     {
      ApplyLevels(forming);
      gLevelsBar = forming;
     }
   working.CopyFrom(committed);
   working.OnBar(forming, false, true);
   WriteCandle(forming, working.candleColorIndex);
   if(!alertOnBarCloseInput)
      FireAlerts(working.currentAlerts, forming);

   Render();
   return rates_total;
  }
//+------------------------------------------------------------------+
