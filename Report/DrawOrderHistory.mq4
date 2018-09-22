//+------------------------------------------------------------------+
//|                                             DrawOrderHistory.mq4 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 3

extern int MagicNumber = 0;
extern string Comments = "";

double OpenBuyArrow[],OpenSellArrow[],CloseArrow[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexStyle(0,DRAW_ARROW,EMPTY,1,Green);
   SetIndexArrow(0,221);
   SetIndexBuffer(0,OpenBuyArrow);
   SetIndexLabel(0,"Buy Order Open Price");
   
   SetIndexStyle(1,DRAW_ARROW,EMPTY,1,Red);
   SetIndexArrow(1,222);
   SetIndexBuffer(1,OpenSellArrow);
   SetIndexLabel(1,"Sell Order Open Price");
   
   SetIndexStyle(2,DRAW_ARROW,EMPTY,1,DarkOrange);
   SetIndexArrow(2,251);
   SetIndexBuffer(2,CloseArrow);
   SetIndexLabel(2,"Close Price");
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
//---
   int totalHistory = OrdersHistoryTotal()-1;
   for(int i=0;i<totalHistory;i++){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))continue;
      //if(OrderMagicNumber()!=MagicNumber)continue;
      if(OrderComment() != Comments)continue;
      if(OrderSymbol() != Symbol())continue;
      int openBar = iBarShift(OrderSymbol(),0,OrderOpenTime());
      int closeBar = iBarShift(OrderSymbol(),0,OrderCloseTime());
      
      if(OrderType()==0){
         OpenBuyArrow[openBar] = OrderOpenPrice();
      }
      
      if(OrderType()==1){
         OpenSellArrow[openBar] = OrderOpenPrice();
      }
      
      CloseArrow[closeBar]=OrderClosePrice();
      
      SetObj(OrderTicket(),OrderType(),OrderOpenTime(),OrderOpenPrice(),
            OrderCloseTime(),OrderClosePrice());
   }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+


void SetObj(int ticket, int orderType, datetime openTime, double openPrice, 
      datetime closeTime, double closePrice){
   string objName = IntegerToString(ticket,0); 
   ObjectCreate(objName,OBJ_TREND,0,openTime,openPrice,closeTime,closePrice);
   if(orderType==0)ObjectSet(objName,OBJPROP_COLOR,Green);
   if(orderType==1)ObjectSet(objName,OBJPROP_COLOR,Red);
   
   ObjectSet(objName,OBJPROP_STYLE,STYLE_DOT);
   ObjectSet(objName,OBJPROP_WIDTH,3);
   ObjectSet(objName,OBJPROP_BACK,false);
   ObjectSet(objName,OBJPROP_RAY,false);
}

void SetLabel(string name, string content, int x, int y, int fontSize, string style, color pColor){
   ObjectCreate(name,OBJ_LABEL,0,0,0);
   ObjectSetText(name, content,fontSize,style, pColor);
   ObjectSet(name,OBJPROP_XDISTANCE,x);
   ObjectSet(name, OBJPROP_YDISTANCE,y);
}