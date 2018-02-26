//+------------------------------------------------------------------+
//|                                                          BB MACD |
//|                                      Copyright ?2009, EarnForex |
//|                                        http://www.earnforex.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright ?2009, EarnForex"
#property link      "http://www.earnforex.com"
#property version   "1.01"
#property description "BB MACD - Bollinger Bands with MACD mutation based on Moving Averages"
#property description "and Standard Deviation indicators."

//---- indicator settings
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   3
#property indicator_color1  Lime, Magenta    //Up/down bullets
#property indicator_type1   DRAW_COLOR_ARROW
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
#property indicator_color2  Blue    //Upperband
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
#property indicator_color3  Red     //Lowerband
#property indicator_type3   DRAW_LINE
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//---- indicator parameters
input int FastLen = 12;
input int SlowLen = 26;
input int Length = 10;
input int barsCount = 400;
input double StDv = 2.5;

//---- indicator buffers
double ExtMapBuffer1[];  // bbMacd
double ExtMapBuffer2[];  // bbMacd Color
double ExtMapBuffer3[];  // Upperband Line
double ExtMapBuffer4[];  // Lowerband Line
double ExtMapBuffer5[];  // Data for "iMAOnArray()"

double MABuff1[];
double MABuff2[];
double bbMacd[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
{
 	IndicatorSetString(INDICATOR_SHORTNAME, "BB MACD(" + IntegerToString(FastLen) + "," + IntegerToString(SlowLen) + "," + IntegerToString(Length) + ")");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 1);

//---- indicator buffers mapping
   SetIndexBuffer(0, ExtMapBuffer1, INDICATOR_DATA);
   SetIndexBuffer(1, ExtMapBuffer2, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, ExtMapBuffer3, INDICATOR_DATA);
   SetIndexBuffer(3, ExtMapBuffer4, INDICATOR_DATA);
   SetIndexBuffer(4, ExtMapBuffer5, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, MABuff1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, MABuff2, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, bbMacd, INDICATOR_CALCULATIONS);

   //Set the correct order: 0 is the latest, N - is the oldest
   ArraySetAsSeries(ExtMapBuffer1, true);
   ArraySetAsSeries(ExtMapBuffer2, true);
   ArraySetAsSeries(ExtMapBuffer3, true);
   ArraySetAsSeries(ExtMapBuffer4, true);
   ArraySetAsSeries(ExtMapBuffer5, true);
   ArraySetAsSeries(MABuff1, true);
   ArraySetAsSeries(MABuff2, true);
   ArraySetAsSeries(bbMacd, true);
   
   PlotIndexSetInteger(0, PLOT_ARROW, 108);
   
//---- name for DataWindow and indicator subwindow label
   PlotIndexSetString(0, PLOT_LABEL, "bbMacd");
   PlotIndexSetString(2, PLOT_LABEL, "Upperband");
   PlotIndexSetString(3, PLOT_LABEL, "Lowerband");  
}

//+------------------------------------------------------------------+
//| Custom BB_MACD                                                   |
//+------------------------------------------------------------------+
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
   int limit;

   int counted_bars = prev_calculated;
   if (counted_bars < 0) return(-1);
   if (counted_bars > 0) counted_bars--;
   if (barsCount > 0) limit = MathMin((rates_total - counted_bars), barsCount);
   else  limit = rates_total - counted_bars;
//----
   int myMA = iMA(NULL, 0, FastLen, 0, MODE_EMA, PRICE_CLOSE);
   if (CopyBuffer(myMA, 0, 0, rates_total, MABuff1) != rates_total) return(0);
   myMA = iMA(NULL, 0, SlowLen, 0, MODE_EMA, PRICE_CLOSE);
   if (CopyBuffer(myMA, 0, 0, rates_total, MABuff2) != rates_total) return(0);

   for (int i = 0; i < limit; i++)
       bbMacd[i] = MABuff1[i] - MABuff2[i];

//----
   CalculateEMA(limit - 1, Length, bbMacd);
   
   for (int i = 0; i < limit; i++)
   {
      double avg = ExtMapBuffer5[i]; // MA on Array
		double sDev = StdDevFunc(i, Length, bbMacd); //StdDev on Array
      
      ExtMapBuffer1[i] = bbMacd[i];     // bbMacd
      if (bbMacd[i] > bbMacd[i + 1]) ExtMapBuffer2[i] = 0;      // Uptrend
      else if (bbMacd[i] < bbMacd[i + 1]) ExtMapBuffer2[i] = 1; // Downtrend
      
      ExtMapBuffer3[i] = avg + (StDv * sDev);  // Upperband
      ExtMapBuffer4[i] = avg - (StDv * sDev);  // Lowerband
   }
   return(rates_total);
}

//+------------------------------------------------------------------+
//|  Exponential Moving Average                                      |
//|  Fills the buffer array with EMA values.									|
//+------------------------------------------------------------------+
void CalculateEMA(int begin, int period, const double &price[])
{
   double SmoothFactor = 2.0 / (1.0 + period);
	int start;
	
   //First time
   if (ExtMapBuffer5[ArrayMaximum(ExtMapBuffer5)] <= 0)
   {
   	ExtMapBuffer5[begin] = price[begin];
   	start = begin - 1;
   }
   else start = begin;

   for(int i = start; i >= 0; i--) ExtMapBuffer5[i] = price[i] * SmoothFactor + ExtMapBuffer5[i + 1] * (1.0 - SmoothFactor);
}

//+------------------------------------------------------------------+
//| Calculate Standard Deviation                                     |
//| Returns StdDev for the given position (bar).                     |
//+------------------------------------------------------------------+
double StdDevFunc(int position, int period, const double &price[])
{
   double dTmp = 0.0;
   for (int i = 0; i < period; i++)	dTmp += MathPow(price[position + i] - ExtMapBuffer5[position], 2);
   dTmp = MathSqrt(dTmp / period);

   return(dTmp);
}
//+------------------------------------------------------------------+
 