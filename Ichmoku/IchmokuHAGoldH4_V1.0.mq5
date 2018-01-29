//+------------------------------------------------------------------+
//|                                         IchmokuHAGoldH4_V2.0.mq5 |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#define EXPERT_MAGIC 20180129


#include <IchomuSignal.mqh>

enum mm     {classic        //Classic
            ,mart           //Martingale
            ,r_mart         //Anti-Martingale
            ,scale          //Scale-in Profit
            ,r_scale        //Scale-in Loss
            ,};
            
extern mm mm_mode = r_scale;                        //Money Management

extern double blots = 0.02;                         //Base lot size
extern double cator = 1.1;                          //Martingale multiplicator
extern double f_inc = 0.01;                          //Scaler increment

class CMyExpert {

protected:
   double            m_adjusted_point;             // point value adjusted for 3 or 5 points
   CTrade            m_trade;                      // trading object
   CSymbolInfo       m_symbol;                     // symbol info object
   CPositionInfo     m_position;                   // trade position object
   CAccountInfo      m_account;                    // account info wrapper
   CStrategy         m_strategy;
   int               m_strategy_mode;

public:
                     CMyExpert(void);
                    ~CMyExpert(void);
   bool              Init(void);
   void              Deinit(void);
   bool              Processing(void);
   SIGNAL_DIRECTION  SIGNAL_DIRECTION getSignal();
protected:
   bool              InitCheckParameters(const int digits_adjust);
   bool              InitIndicators(void);
   bool              LongClosed(void);
   bool              ShortClosed(void);
   bool              LongModified(void);
   bool              ShortModified(void);
   bool              LongOpened(void);
   bool              ShortOpened(void);
   double            GetOrderLots(void);
   double            Counta(int key,string name=NULL);
};

//--- global expert
CMyExpert ExtExpert;
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMyExpert::CMyExpert(void) : m_adjusted_point(0),
                                     m_handle_macd(INVALID_HANDLE),
                                     m_handle_ema(INVALID_HANDLE),
                                     m_macd_current(0),
                                     m_macd_previous(0),
                                     m_signal_current(0),
                                     m_signal_previous(0),
                                     m_ema_current(0),
                                     m_ema_previous(0),
                                     m_macd_open_level(0),
                                     m_macd_close_level(0),
                                     m_traling_stop(0),
                                     m_take_profit(0)
  {
   ArraySetAsSeries(m_buff_MACD_main,true);
   ArraySetAsSeries(m_buff_MACD_signal,true);
   ArraySetAsSeries(m_buff_EMA,true);
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMyExpert::~CMyExpert(void)
  {
  }
//+------------------------------------------------------------------+
//| Initialization and checking for input parameters                 |
//+------------------------------------------------------------------+
bool CMyExpert::Init(void)
  {
//--- initialize common information
   m_symbol.Name(Symbol());                  // symbol
   m_trade.SetExpertMagicNumber(EXPERT_MAGIC); // magic
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(Symbol());
//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_adjusted_point=m_symbol.Point()*digits_adjust;
//--- set default deviation for trading in adjusted points
   // m_macd_open_level =InpMACDOpenLevel*m_adjusted_point;
   // m_macd_close_level=InpMACDCloseLevel*m_adjusted_point;
   // m_traling_stop    =InpTrailingStop*m_adjusted_point;
   // m_take_profit     =InpTakeProfit*m_adjusted_point;
//--- set default deviation for trading in adjusted points
   m_trade.SetDeviationInPoints(3*digits_adjust);
//---
   if(!InitCheckParameters(digits_adjust))
      return(false);
   if(!InitIndicators())
      return(false);
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Checking for input parameters                                    |
//+------------------------------------------------------------------+
bool CMyExpert::InitCheckParameters(const int digits_adjust)
  {
//--- initial data checks
//    if(InpTakeProfit*digits_adjust<m_symbol.StopsLevel())
//      {
//       printf("Take Profit must be greater than %d",m_symbol.StopsLevel());
//       return(false);
//      }
//    if(InpTrailingStop*digits_adjust<m_symbol.StopsLevel())
//      {
//       printf("Trailing Stop must be greater than %d",m_symbol.StopsLevel());
//       return(false);
//      }
// //--- check for right lots amount
//    if(InpLots<m_symbol.LotsMin() || InpLots>m_symbol.LotsMax())
//      {
//       printf("Lots amount must be in the range from %f to %f",m_symbol.LotsMin(),m_symbol.LotsMax());
//       return(false);
//      }
//    if(MathAbs(InpLots/m_symbol.LotsStep()-MathRound(InpLots/m_symbol.LotsStep()))>1.0E-10)
//      {
//       printf("Lots amount is not corresponding with lot step %f",m_symbol.LotsStep());
//       return(false);
//      }
// //--- warning
//    if(InpTakeProfit<=InpTrailingStop)
//       printf("Warning: Trailing Stop must be less than Take Profit");
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Initialization of the indicators                                 |
//+------------------------------------------------------------------+
bool CMyExpert::InitIndicators(void)
  {
//--- create MACD indicator
//    if(m_handle_macd==INVALID_HANDLE)
//       if((m_handle_macd=iMACD(NULL,0,12,26,9,PRICE_CLOSE))==INVALID_HANDLE)
//         {
//          printf("Error creating MACD indicator");
//          return(false);
//         }
// //--- create EMA indicator and add it to collection
//    if(m_handle_ema==INVALID_HANDLE)
//       if((m_handle_ema=iMA(NULL,0,InpMATrendPeriod,0,MODE_EMA,PRICE_CLOSE))==INVALID_HANDLE)
//         {
//          printf("Error creating EMA indicator");
//          return(false);
//         }
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Check for long position closing                                  |
//+------------------------------------------------------------------+
bool CMyExpert::LongClosed(void)
  {
   	bool res=false;

    //--- close position
    if(m_trade.PositionClose(m_symbol.Name())){
    	res = true;
       	printf("Long position by %s to be closed",Symbol());
    }
    else{
       printf("Error closing position by %s : '%s'",Symbol(),m_trade.ResultComment());
    }
            
   	return(res);
  }
//+------------------------------------------------------------------+
//| Check for short position closing                                 |
//+------------------------------------------------------------------+
bool CMyExpert::ShortClosed(void)
  {
   	bool res=false;
    //--- close position
    if(m_trade.PositionClose(m_symbol.Name())){
    	res = true;
       printf("Short position by %s to be closed",Symbol());
    }
    else{
       printf("Error closing position by %s : '%s'",Symbol(),m_trade.ResultComment());
    }
   	return(res);
  }
//+------------------------------------------------------------------+
//| Check for long position modifying                                |
//+------------------------------------------------------------------+
bool CMyExpert::LongModified(void)
  {
   bool res=false;
//--- check for trailing stop
   if(InpTrailingStop>0)
     {
      if(m_symbol.Bid()-m_position.PriceOpen()>m_adjusted_point*InpTrailingStop)
        {
         double sl=NormalizeDouble(m_symbol.Bid()-m_traling_stop,m_symbol.Digits());
         double tp=m_position.TakeProfit();
         if(m_position.StopLoss()<sl || m_position.StopLoss()==0.0)
           {
            //--- modify position
            if(m_trade.PositionModify(Symbol(),sl,tp))
               printf("Long position by %s to be modified",Symbol());
            else
              {
               printf("Error modifying position by %s : '%s'",Symbol(),m_trade.ResultComment());
               printf("Modify parameters : SL=%f,TP=%f",sl,tp);
              }
            //--- modified and must exit from expert
            res=true;
           }
        }
     }
//--- result
   return(res);
  }
//+------------------------------------------------------------------+
//| Check for short position modifying                               |
//+------------------------------------------------------------------+
bool CMyExpert::ShortModified(void)
  {
   bool   res=false;
//--- check for trailing stop
   if(InpTrailingStop>0)
     {
      if((m_position.PriceOpen()-m_symbol.Ask())>(m_adjusted_point*InpTrailingStop))
        {
         double sl=NormalizeDouble(m_symbol.Ask()+m_traling_stop,m_symbol.Digits());
         double tp=m_position.TakeProfit();
         if(m_position.StopLoss()>sl || m_position.StopLoss()==0.0)
           {
            //--- modify position
            if(m_trade.PositionModify(Symbol(),sl,tp))
               printf("Short position by %s to be modified",Symbol());
            else
              {
               printf("Error modifying position by %s : '%s'",Symbol(),m_trade.ResultComment());
               printf("Modify parameters : SL=%f,TP=%f",sl,tp);
              }
            //--- modified and must exit from expert
            res=true;
           }
        }
     }
//--- result
   return(res);
  }

double CMyExpert ::  GetOrderLots(string name){
	//--- Money Management
	double mlots=0;
	int WinCount = Counta(6,name);
	int LossCount = Counta(5,name);
	switch(mm_mode){

	// //Martingale
	//    case mart: if (OrdersHistoryTotal()!=0) mlots=NormalizeDouble(blots*(MathPow(cator,(LossCount))),2); else mlots = blots; break;
	   
	// //Reversed Martingale
	//    case r_mart: if (OrdersHistoryTotal()!=0) mlots=NormalizeDouble(blots*(MathPow(cator,(WinCount))),2); else mlots = blots; break;
	   
	//Scale after loss (Fixed)
	   case scale: if (OrdersHistoryTotal()!=0) mlots=blots+(f_inc*WinCount); else mlots = blots; break;
	   
	//Scale after win (Fixed)
	   case r_scale: if (OrdersHistoryTotal()!=0) mlots=blots+(f_inc*LossCount); else mlots = blots; break;
	   
	//Classic
	   case classic: mlots = blots; break;
	};
	return mlots;
}

double CMyExpert :: Counta (int key, string name=NULL){

   double count_tot = 0;
   
   switch (key) {
   //Chain Loss
   case(5):
     for (int i = 0; i < OrdersHistoryTotal(); i++) 
    {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) 
        continue;
         if (OrderMagicNumber() == EXPERT_MAGIC && OrderSymbol() == name && OrderProfit()<0) 
        {count_tot++;}
         if (OrderMagicNumber() == EXPERT_MAGIC && OrderSymbol() == name && OrderProfit()>0)
          {count_tot=0;}
     }
   break;
   
   //Chain Win
   case(6):
     for (int i = 0; i < OrdersHistoryTotal(); i++) 
    {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) 
        continue;
         if (OrderMagicNumber() == EXPERT_MAGIC && OrderSymbol() == name && OrderProfit()<0) 
        {count_tot=0;}
         if (OrderMagicNumber() == EXPERT_MAGIC && OrderSymbol() == name && OrderProfit()>0)
          {count_tot++;}
    }
   	break;
   }
   return count_tot;
}
//+------------------------------------------------------------------+
//| Check for long position opening                                  |
//+------------------------------------------------------------------+
bool CMyExpert::LongOpened(void)
  {
   bool res=false;
//--- check for long position (BUY) possibility
// MACD value below the zero line and start to bigger than the signal line(diff value 
//   moving average)
// Ma value bigger than the previous one
// MACD current value bigger than the open value
	int result = 0;
	double mlots = getOrderLots(name);
	string long_comment = "HA_SMA-long on strategy_" + IntegerToString(strategy);
	result=OrderSend(name,OP_BUY,mlots,MarketInfo(name, MODE_ASK),Slippage,0,0,long_comment,MagicNumber,0,Turquoise);
	if(result>0){
		//log("IchomuA=="+IchomuA + " IchomuB==" + IchomuB + " Close[shift]==>"+Close[shift] + "ichomuTrend=="+ichomuTrend);
		double TP = 0, SL = 0;
		double SLp = 0, TPp = 0,  TSp = 0; 
		calculateStopLoss(name,SLp, TPp, TSp);
		if(TPp>0) TP=MarketInfo(name, MODE_ASK)+TPp;
		if(SLp>0) SL=MarketInfo(name, MODE_ASK)-SLp;
		bool success=false;
		int retry = 0;
		if(OrderSelect(result,SELECT_BY_TICKET))
		while(!success && retry < 4){
		  success = OrderModify(OrderTicket(),OrderOpenPrice(),NormalizeDouble(SL,(int)MarketInfo(name, MODE_DIGITS))
		    ,NormalizeDouble(TP,(int)MarketInfo(name, MODE_DIGITS)),0,Green);
		  retry++;
		}
	}
   
    double price=m_symbol.Ask();
    double tp   =m_symbol.Bid()+m_take_profit;
    //--- check for free money
    if(m_account.FreeMarginCheck(Symbol(),ORDER_TYPE_BUY,mlots,price)<0.0)
       printf("We have no money. Free Margin = %f",m_account.FreeMargin());
    else {
       //--- open position
        if(m_trade.PositionOpen(Symbol(),ORDER_TYPE_BUY,mlots,price,0.0,0.0)){
            printf("Position by %s to be opened",Symbol());
            
        }else{
            printf("Error opening BUY position by %s : '%s'",Symbol(),m_trade.ResultComment());
            printf("Open parameters : price=%f,TP=%f",price,tp);
        }
    }
           
//--- result
   return(res);
  }
//+------------------------------------------------------------------+
//| Check for short position opening                                 |
//+------------------------------------------------------------------+
bool CMyExpert::ShortOpened(void)
  {
   bool res=false;
//--- check for short position (SELL) possibility
   if(m_macd_current>0)
      if(m_macd_current<m_signal_current && m_macd_previous>m_signal_previous)
         if(m_macd_current>(m_macd_open_level) && m_ema_current<m_ema_previous)
           {
            double price=m_symbol.Bid();
            double tp   =m_symbol.Ask()-m_take_profit;
            //--- check for free money
            if(m_account.FreeMarginCheck(Symbol(),ORDER_TYPE_SELL,InpLots,price)<0.0)
               printf("We have no money. Free Margin = %f",m_account.FreeMargin());
            else
              {
               //--- open position
               if(m_trade.PositionOpen(Symbol(),ORDER_TYPE_SELL,InpLots,price,0.0,tp))
                  printf("Position by %s to be opened",Symbol());
               else
                 {
                  printf("Error opening SELL position by %s : '%s'",Symbol(),m_trade.ResultComment());
                  printf("Open parameters : price=%f,TP=%f",price,tp);
                 }
              }
            //--- in any case we must exit from expert
            res=true;
           }
//--- result
   return(res);
  }
//+------------------------------------------------------------------+
//| main function returns true if any position processed             |
//+------------------------------------------------------------------+
bool CMyExpert::Processing(void)
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
      return(false);
//--- refresh indicators
   //if(BarsCalculated(m_handle_macd)<2 || BarsCalculated(m_handle_ema)<2)
     // return(false);
//    if(CopyBuffer(m_handle_macd,0,0,2,m_buff_MACD_main)  !=2 ||
//       CopyBuffer(m_handle_macd,1,0,2,m_buff_MACD_signal)!=2 ||
//       CopyBuffer(m_handle_ema,0,0,2,m_buff_EMA)         !=2)
//       return(false);
// //   m_indicators.Refresh();
// //--- to simplify the coding and speed up access
// //--- data are put into internal variables
//    m_macd_current   =m_buff_MACD_main[0];
//    m_macd_previous  =m_buff_MACD_main[1];
//    m_signal_current =m_buff_MACD_signal[0];
//    m_signal_previous=m_buff_MACD_signal[1];
//    m_ema_current    =m_buff_EMA[0];
//    m_ema_previous   =m_buff_EMA[1];
//--- it is important to enter the market correctly, 
//--- but it is more important to exit it correctly...   
//--- first check if position exists - try to select it
   if(m_position.Select(Symbol()))
     {
      if(m_position.PositionType()==POSITION_TYPE_BUY)
        {
         //--- try to close or modify long position
         if(LongClosed())
            return(true);
         if(LongModified())
            return(true);
        }
      else
        {
         //--- try to close or modify short position
         if(ShortClosed())
            return(true);
         if(ShortModified())
            return(true);
        }
     }
//--- no opened position identified
   else
     {
      //--- check for long position (BUY) possibility
      if(LongOpened())
         return(true);
      //--- check for short position (SELL) possibility
      if(ShortOpened())
         return(true);
     }
//--- exit without position processing
   return(false);
  }
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
  }
//+------------------------------------------------------------------+
