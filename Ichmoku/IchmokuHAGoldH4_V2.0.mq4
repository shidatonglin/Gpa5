/*         
          o=======================================o
         //                                       \\ 
         O                Gold H4                   O
        ||               by tony tong               ||
        ||             (xxxxxxxxxxxxx)              ||                    
        ||           shidatonglin@gmail.com         ||
         O           __________________             O
         \\                                       //
          o=======================================o                                                               

*/

#property copyright     "shidatonglin"
#property link          "shidatonglin@gmail.com (mp me on FF rather than by email)"
#property description   "Gold H4 Ichomu"
#property strict

/*
https://www.forexfactory.com/showthread.php?t=670701
https://www.forexfactory.com/showthread.php?t=656770#acct.42
Basic Tools
 - Heiken Ashi
 - 2 Lines Moving Average (Period: 5, Method: Smoothed, Shift: 2, Apply: High and Low)
 - Ichimoku kinko hyo (Tenkan_sen: 9, Kijun_sen: 26, Senkou_Span_B: 60)
 (My Template is below)

My Rule
Entry Buy
 - Heiken Ashi is above Ichimoku kinko hyo Cloud
 - Heiken Ashi is above Moving Average (Apply: High)
 - Open Next Bar

Exit Buy
 - Heiken Ashi is below Moving Average (Apply: Low)
 - Open Next Bar.

Entry Sell
 - Heiken Ashi is below Ichimoku kinko hyo Cloud
 - Heiken Ashi is below Moving Average (Apply: Low)
 - Open Next Bar

Exit Sell
 - Heiken Ashi is above Moving Average (Apply: High)
 - Open Next Bar.

Money Management
 Deposit (minimum): 1,000 (Fixed lot MM_Martingale_Start 0.01 and MM_Martingale_LossFactor +0.01 per each 1000 units of the deposit currency.)
 Martingale Start: 0.01
 Leverage: 1:500
 Martingale After Loss Factor: +0.01
 Example 1:
 Martingale Start = 0.01
 Martingale After Loss Factor 0.01+0.01 = 0.02 .. >> 0.03 >> 0.04 >> 0.05 until Profitable last exit after that restart initial lot = 0.01


Currency Gold / XAUUSD
Time Frame: H4

*/

//--- external variables
extern bool enableTrade = true;                    // Enable EA
extern bool basketTrade = true;                    // BasketTrade or not
enum Trade_Mode {
  HA_Ichomu        =1,
  HA_Ichomu_BBmacd =2,
  BB_macd_cross    =3,
  MA_Channel_Cross =4,
  MACDCross        =5
};
extern Trade_Mode strategy  = HA_Ichomu_BBmacd;
extern double atr_p = 15;                           //ATR/HiLo period for dynamic SL/TP/TS
extern double atr_x = 1;                            //ATR weight in SL/TP/TS
extern int    atr_tf = 240;
extern double hilo_x = 0.5;                         //HiLo weight in SL/TP/TS
double sl_p = 0;                                    //Raw pips offset

extern double pf = 20;                             //Targeted profit factor (x times SL)

extern bool trail_mode = true;                      //Enable trailing
extern double tf = 0.8;                             //Trailing factor (x times Sl)

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
extern bool close_range = false;                    //Close on range
extern bool close_r = false;                        //Close on direction change
extern bool r_signal = false;                       //Reversed signal

extern bool gui = false;                             //Show The EA GUI

extern color color1 = LightGray;                    //EA's name color
extern color color2 = DarkOrange;                   //EA's balance & info color
extern color color3 = Turquoise;                    //EA's profit color
extern color color4 = Magenta;                      //EA's loss color

extern int Slippage = 3;                          
extern int MagicNumber = 20180207;                       //Magic

extern int High_TF  = 1440;
extern int Low_TF   = 240;
extern bool UseCurrent = false;
extern int MaxTrade  = 1;
extern int HoursBetween = 0;

extern int MaPeriod = 5;
extern int MaShift  = 2;
extern int MaMode = MODE_SMMA;
//--- inner variables

string version = "0.2";

double max_acc_dd = 0;
double max_acc_dd_pc = 0;
double max_dd = 0;
double max_dd_pc = 0;
double max_acc_runup = 0;
double max_acc_runup_pc = 0;
double max_runup = 0;
double max_runup_pc = 0;
int max_chain_win = 0;
int max_chain_loss = 0;
int shift = 0;
int spread = 0;
int lastOrderTime = 0;

string pairs[];
//---

int init() {
  //getAvailableCurrencyPairs(pairs);
  Assign28SymbolToList(pairs);
  if(!UseCurrent) shift = 1;
   return (0);
}

int deinit() {
  if(ObjectFind( "HUD" )>=0)ObjectDelete( "HUD" );
  int obj_total=ObjectsTotal();
  PrintFormat("Total %d objects",obj_total);
  for(int i=obj_total-1;i>=0;i--)
  {
    string name=ObjectName(i);
    PrintFormat("object %d: %s",i,name);
    if(StringFind(name, version,0)>-1){
      ObjectDelete(name);
    }
  }
  
   return (0);
}

datetime preTime = 0;

int start(){
  // if (gui) {
  //   HUD();
  //   Popup();
  //   Earnings();
  // }
  if(gui)printTradePairs(pairs);
  // trail stop
  if(trail_mode) trail_stop();

  if(!enableTrade) return;

  // New bar, check open
  if(preTime < Time[0]){
    // New bar generated
    if(basketTrade){
      int total_pairs = ArraySize( pairs );
      for(int index=0; index <  total_pairs; index++){
        if(TotalOrdersCount(pairs[index]) > 0) checkForClose(pairs[index]);
        else checkForOpen(pairs[index]);
      }
    } else {
      string currentSymbol = Symbol();
      if(TotalOrdersCount(currentSymbol) > 0) checkForClose(currentSymbol);
      else checkForOpen(currentSymbol);
    }
    
    preTime = Time[0];
  }
  return(0);
}

void printTradePairs(string& myPairs[]){
  string text = "";
  for(int i=0;i<ArraySize(myPairs);i++){
     text = text + myPairs[i] + " , ";
     if(i%10==0) text = text + "\n";
  }
  Comment(text);
}


void checkForOpen(string name){
  int signal = getSignal(name);
  if(signal == 1) open_buy(name);
  else if(signal == -1) open_sell(name);
}

bool checkSpread(string name){

  return true;
}

void checkForClose(string name){
  int exit_signal = getExitSignal(name);
  if(exit_signal == -1) close_buy(name);
  if(exit_signal == 1) close_sell(name);
}

//+------------------------------------------------------------------+
int getAvailableCurrencyPairs(string& availableCurrencyPairs[], const bool selected=false)
{
//---   
  const int symbolsCount = SymbolsTotal(selected);
  int currencypairsCount;
  ArrayResize(availableCurrencyPairs, symbolsCount);
  int idxCurrencyPair = 0;
  for(int idxSymbol = 0; idxSymbol < symbolsCount; idxSymbol++)
   {      
      string symbol = SymbolName(idxSymbol, selected);
      string firstChar = StringSubstr(symbol, 0, 1);
      if(firstChar != "#" && StringLen(symbol) == 6)
        {        
          availableCurrencyPairs[idxCurrencyPair++] = symbol; 
        } 
  }
  currencypairsCount = idxCurrencyPair;
  ArrayResize(availableCurrencyPairs, currencypairsCount);
  return currencypairsCount;
}

/*
 * return value : -1:down, 1:up, 0: none
 */
int getSignal(string name){
// Original
// Ichomu + Machannal
// Everytime if HA close price bigger than ichomu high cloud and ma channal high
// Then open buy
   if(strategy == HA_Ichomu) return getSignalStrategy1(name);

// Ichomu + Machannal + BB_macd
// Base strategy 1, add filter when buy, bb_macd should blue
// when sell bb_macd should red
   if(strategy == HA_Ichomu_BBmacd) return getSignalStrategy2(name);

// BB_macd 
// Everytime when bb_macd value cross up/down its upper band or lower band
// and price be higher or lower than the ma channel high or low
   if(strategy == BB_macd_cross) return getSignalStrategy3(name);

// Ma channel cross
// Buy:
//     Everytime when HA close price cross up ma channel high
//     Ha close price higher than Ichomu upper cloud
//     BB macd should be blue
// Sell:
//     Everytime when HA close price cross down ma channel low
//     Ha close price lower than Ichomu bottom cloud
//     BB macd should be blue
   if(strategy == MA_Channel_Cross) return getSignalStrategy4(name);

   // Strategy 5
   // Only for index CDFs currently.
   // Macd value > 0 and current value > current signal value 
   //                and previous value < previous signal value---->buy
   // Macd value < 0 and current value < current signal value 
   //                and previous value > previous signal value---->sell
   if(strategy == MACDCross) return getSignalStrategy5(name);

  return 0;
}


int getIchomuTrendSignal(string name){
  int ichomuTrendLowTF = 0;
  double IchomuC = iIchimoku(name, Low_TF , 12 , 29 , 52 , 3 , shift);
  double IchomuD = iIchimoku(name, Low_TF , 12 , 29 , 52 , 4 , shift);
  // HA close value
  double haClose = iCustom(name, Low_TF, "Heiken Ashi", 0,0,0,0, 3, shift);

  if(haClose > IchomuC && haClose > IchomuD){
    ichomuTrendLowTF = 1;
  }

  if(haClose < IchomuC && haClose < IchomuD){
    ichomuTrendLowTF = -1;
  }
  return ichomuTrendLowTF;
}

int getIchomuCrossSignal(string name)
  {
   int ichomuTrendLowTF=0;
   double IchomuC = iIchimoku(name, Low_TF , 12 , 29 , 52 , 3 , shift);
   double IchomuD = iIchimoku(name, Low_TF , 12 , 29 , 52 , 4 , shift);
// HA close value
   double haClose=iCustom(name,Low_TF,"Heiken Ashi",0,0,0,0,3,shift);

   double pre_IchomuC = iIchimoku(name, Low_TF , 12 , 29 , 52 , 3 , shift+1);
   double pre_IchomuD = iIchimoku(name, Low_TF , 12 , 29 , 52 , 4 , shift+1);
// HA close value
   double pre_haClose=iCustom(name,Low_TF,"Heiken Ashi",0,0,0,0,3,shift+1);

//if((haClose > IchomuC && haClose > IchomuD)
//   && (pre_haClose<pre_IchomuC || pre_haClose<pre_IchomuD)){
//  ichomuTrendLowTF = 1;
//}

   if(haClose>MathMax(IchomuC,IchomuD)
      && pre_haClose<MathMax(pre_IchomuC,pre_IchomuD))ichomuTrendLowTF=1;

   if(haClose<MathMin(IchomuC,IchomuD)
      && pre_haClose>MathMin(pre_IchomuC,pre_IchomuD))ichomuTrendLowTF=-1;

//if(haClose < IchomuC && haClose < IchomuD){
//  ichomuTrendLowTF = -1;
//}
   return ichomuTrendLowTF;
  }

int getMaChannalSignal(string name){
  // Two MA channels
  int maChannelCross = 0;
  double maHigh = iMA( name, Low_TF, MaPeriod, MaShift, MaMode, PRICE_HIGH, shift);
  double maLow = iMA( name, Low_TF, MaPeriod, MaShift, MaMode, PRICE_LOW, shift);
  double haClose = iCustom(name, Low_TF, "Heiken Ashi", 0,0,0,0, 3, shift);
  if(haClose > maHigh) maChannelCross = 1;
  if(haClose < maLow) maChannelCross = -1;
  return maChannelCross;
}

int getMaChannalCrossSignal(string name)
  {
   int maChannelCross=0;
   double maHigh= iMA(name,Low_TF,MaPeriod,MaShift,MaMode,PRICE_HIGH,shift);
   double maLow = iMA(name,Low_TF,MaPeriod,MaShift,MaMode,PRICE_LOW,shift);
   double haClose=iCustom(name,Low_TF,"Heiken Ashi",0,0,0,0,3,shift);
   double pre_maHigh= iMA(name,Low_TF,MaPeriod,MaShift,MaMode,PRICE_HIGH,shift+1);
   double pre_maLow = iMA(name,Low_TF,MaPeriod,MaShift,MaMode,PRICE_LOW,shift+1);
   double pre_haClose=iCustom(name,Low_TF,"Heiken Ashi",0,0,0,0,3,shift+1);

   if(haClose>maHigh && pre_haClose<pre_maHigh) maChannelCross=1;
   if(haClose<maLow  &&  pre_haClose>pre_maLow) maChannelCross=-1;
   return maChannelCross;
  }

int getMacdValueSignal(string name){
  int macd_signal = 0;
  double main_value = iMACD(name,0,12,26,9,PRICE_CLOSE,MODE_MAIN,shift);
  double signal_value = iMACD(name,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,shift);
  if(main_value > signal_value && main_value > 0) macd_signal = 1;
  if(main_value < signal_value && main_value < 0) macd_signal = -1;
  return macd_signal;
}

int getMacdCrossSignal(string name){
  int macd_signal = 0;
  double pre_main_value = iMACD(name,0,12,26,9,PRICE_CLOSE,MODE_MAIN,shift+1);
  double pre_signal_value = iMACD(name,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,shift+1);
  double main_value = iMACD(name,0,12,26,9,PRICE_CLOSE,MODE_MAIN,shift);
  double signal_value = iMACD(name,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,shift);
  if(main_value>0 && main_value > signal_value && pre_main_value < pre_signal_value) macd_signal = 1;
  if(main_value<0 && main_value < signal_value && pre_main_value > pre_signal_value) macd_signal = -1;
  return macd_signal;
}

int getBBmacdValueSignal(string name){
  int bb_macd_signal = 0;
  double curUp= iCustom( NULL, Low_TF, "PakuAK_Marblez", 12,26,10,1.0, 0, shift);
  double curDown = iCustom( NULL, Low_TF, "PakuAK_Marblez", 12,26,10,1.0, 1, shift);
  double curUpBand = iCustom( NULL, Low_TF, "PakuAK_Marblez", 12,26,10,1.0, 2, shift);
  double curDownBand = iCustom( NULL, Low_TF, "PakuAK_Marblez", 12,26,10,1.0, 3, shift);

  if(curUp==EMPTY_VALUE) {bb_macd_signal=-1;}
  if(curDown==EMPTY_VALUE) {bb_macd_signal=1;}
  return bb_macd_signal;
}

int getBBmacdCrossSignal(string name){
  int bb_macd_signal = 0;
  double preValue,curValue;
  double preUp= iCustom( NULL, Low_TF, "PakuAK_Marblez", 12,26,10,1.0, 0, 1+shift);
  double preDown = iCustom( NULL, Low_TF, "PakuAK_Marblez", 12,26,10,1.0, 1, 1+shift);
  double preUpBand = iCustom( NULL, Low_TF, "PakuAK_Marblez", 12,26,10,1.0, 2, 1+shift);
  double preDownBand = iCustom( NULL, Low_TF, "PakuAK_Marblez", 12,26,10,1.0, 3, 1+shift);

  if(preUp==EMPTY_VALUE) preValue = preDown;
  if(preDown==EMPTY_VALUE) preValue = preUp;

  double curUp= iCustom( NULL, Low_TF, "PakuAK_Marblez", 12,26,10,1.0, 0, shift);
  double curDown = iCustom( NULL, Low_TF, "PakuAK_Marblez", 12,26,10,1.0, 1, shift);
  double curUpBand = iCustom( NULL, Low_TF, "PakuAK_Marblez", 12,26,10,1.0, 2, shift);
  double curDownBand = iCustom( NULL, Low_TF, "PakuAK_Marblez", 12,26,10,1.0, 3, shift);

  if(curUp==EMPTY_VALUE) curValue = curDown;
  if(curDown==EMPTY_VALUE) curValue = curUp;

  if(preValue > 0 && curValue > 0){
    if(curValue > curUpBand && preValue < preUpBand){
      bb_macd_signal=1;
    }
  }

  if(preValue < 0 && curValue < 0){
    if(curValue < curDownBand && preValue > preDownBand){
      bb_macd_signal=-1;
    }
  }
  return bb_macd_signal;
}

// Ichomu + Machannal
int getSignalStrategy1(string name){
  //Lower TF ichimoku
  int ichomuTrendLowTF = getIchomuTrendSignal(name);

  // Two MA channels
  int maChannelCross = getMaChannalSignal(name);
  //--- Signals

  int signal_1 = 0, signal_2 = 0;
   
  if ( ichomuTrendLowTF == 1 && maChannelCross == 1) signal_1 = 1;
  if ( ichomuTrendLowTF == -1 && maChannelCross == -1) signal_1 = -1;

  signal_2 = signal_1;
  if (r_signal) signal_2 = -signal_1;
  return signal_2;
}

// Ichomu + Machannal + BB_macd
int getSignalStrategy2(string name){

  //Lower TF ichimoku
  int ichomuTrendLowTF = getIchomuTrendSignal(name);

  // Two MA channels
  int maChannelCross = getMaChannalSignal(name);

  // BB macd current value 
  int bb_macd_signal = getBBmacdValueSignal(name);
  //--- Signals

  int signal_1 = 0, signal_2 = 0;
   
  if ( ichomuTrendLowTF == 1 && maChannelCross == 1 && bb_macd_signal==1) signal_1 = 1;
  if ( ichomuTrendLowTF == -1 && maChannelCross == -1 && bb_macd_signal==-1) signal_1 = -1;

  signal_2 = signal_1;
  if (r_signal) signal_2 = -signal_1;
  return signal_2;
}
// BB_macd
int getSignalStrategy3(string name){
  //Lower TF ichimoku
  //int ichomuTrendLowTF = getIchomuTrendSignal(name);

  int bb_macd_signal = getBBmacdCrossSignal(name);

  // Two MA channels
  int maChannelCross = getMaChannalSignal(name);
  //--- Signals

  int signal_1 = 0, signal_2 = 0;
   
  if ( bb_macd_signal == 1 && maChannelCross == 1) signal_1 = 1;
  if ( bb_macd_signal == -1 && maChannelCross == -1) signal_1 = -1;

  signal_2 = signal_1;
  if (r_signal) signal_2 = -signal_1;
  return signal_2;
}

int getSignalStrategy4(string name)
  {

   int bb_macd_signal=getBBmacdValueSignal(name);
// Two MA channels
   int maChannelCross=getMaChannalCrossSignal(name);
   int ichomuSignal=getIchomuTrendSignal(name);
//--- Signals

   int signal_1=0,signal_2=0;

   if( bb_macd_signal == 1 && maChannelCross == 1 && ichomuSignal==1) signal_1 = 1;
   if( bb_macd_signal == -1 && maChannelCross == -1 && ichomuSignal==-1) signal_1 = -1;

   signal_2=signal_1;
   if(r_signal) signal_2=-signal_1;
   return signal_2;
  }

int getSignalStrategy5(string name)
  {

   int macd_signal=getMacdCrossSignal(name);
// Two MA channels
   //int maChannelCross=getMaChannalCrossSignal(name);
   //int ichomuSignal=getIchomuTrendSignal(name);
//--- Signals

   int signal_1=0,signal_2=0;

   if( macd_signal == 1 ) signal_1 = 1;
   if( macd_signal == -1 ) signal_1 = -1;

   signal_2=signal_1;
   if(r_signal) signal_2=-signal_1;
   return signal_2;
  }

int getExitSignal(string name){
  
  // Two MA channels
  // int maChannelCross = 0;
  // double maHigh = iMA( name, Low_TF, MaPeriod, MaShift, MaMode, PRICE_HIGH, shift);
  // double maLow = iMA( name, Low_TF, MaPeriod, MaShift, MaMode, PRICE_LOW, shift);
  // double haClose = iCustom(name, Low_TF, "Heiken Ashi", 0,0,0,0, 3, shift);
  // if(haClose > maHigh) maChannelCross = 1;
  // if(haClose < maLow) maChannelCross = -1;
  
  return getMaChannalSignal(name);
}

void open_buy(string name){
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
}

void open_sell(string name){
  int result = 0;
  double mlots = getOrderLots(name);
  string short_comment = "HA_SMA-short on strategy_" + IntegerToString(strategy);
  result=OrderSend(name,OP_SELL,mlots,MarketInfo(name, MODE_BID),Slippage,0,0,short_comment,MagicNumber,0,Magenta);
  if(result>0){
    //Comment("\n   This Bar has already been traded");
    double TP = 0, SL = 0;
    double SLp = 0,  TPp = 0,  TSp = 0; 
    calculateStopLoss(name, SLp, TPp, TSp);
    if(TPp>0) TP=MarketInfo(name, MODE_BID)-TPp;
    if(SLp>0) SL=MarketInfo(name, MODE_BID)+SLp;
    bool success=false;
    int retry = 0;
    if(OrderSelect(result,SELECT_BY_TICKET))
    while(!success && retry < 4){
      success = OrderModify(OrderTicket(),OrderOpenPrice(),NormalizeDouble(SL,(int)MarketInfo(name, MODE_DIGITS))
        ,NormalizeDouble(TP,(int)MarketInfo(name, MODE_DIGITS)),0,Green);
      retry++;
    }
  }
}

bool close_buy(string name){
  bool success = false;
  for(int cnt=0;cnt<OrdersTotal();cnt++){
    if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
    if(OrderType()<=OP_SELL && OrderSymbol()==name && OrderMagicNumber()==MagicNumber) {
      //--- Close long
      if(OrderType()==OP_BUY){
        success = OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),Slippage,Red);
        return success;
      }
    }
  }
  return success;
}

bool close_sell(string name){
  bool success = false;
  for(int cnt=0;cnt<OrdersTotal();cnt++){
    if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
    if(OrderType()<=OP_SELL && OrderSymbol()==name && OrderMagicNumber()==MagicNumber){
      //--- Close Short
      if(OrderType()==OP_SELL) {
        success = OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),Slippage,Red);
        return success;
      }
    }
  }
  return success;
}

void trail_stop(){

  double SLp = 0,  TPp = 0,  TSp = 0; 
  string name = "";
  for(int cnt=0;cnt<OrdersTotal();cnt++){
    if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
    if(OrderType()<=OP_SELL && OrderMagicNumber()==MagicNumber){
      //--- Close long
      name = OrderSymbol();
      calculateStopLoss(name, SLp, TPp, TSp);
      if(OrderType()==OP_BUY){
        if(TSp>0 && trail_mode==true){                 
          if(MarketInfo(name,MODE_BID) -OrderOpenPrice()>TSp){
            if(OrderStopLoss()<MarketInfo(name,MODE_BID)-TSp){
              OrderModify(OrderTicket(),OrderOpenPrice(),MarketInfo(name,MODE_BID)-TSp,OrderTakeProfit(),0,Turquoise);
              //return success;
            }
          }
        }
      }
      //--- Close Short
      if(OrderType()==OP_SELL){
        if(TSp>0 && trail_mode==true){                 
          if((OrderOpenPrice()-MarketInfo(name,MODE_ASK))>(TSp)){
            if((OrderStopLoss()>(MarketInfo(name,MODE_ASK)+TSp)) || (OrderStopLoss()==0)){
              OrderModify(OrderTicket(),OrderOpenPrice(),MarketInfo(name,MODE_ASK)+TSp,OrderTakeProfit(),0,Magenta);
              //return success;
            }
          }
        }
      }
    }
  }
  //return success;
}

double getOrderLots(string name){
  //--- Money Management
  double mlots=0;
  int WinCount = Counta(6,name);
  int LossCount = Counta(5,name);
  switch(mm_mode){

    //Martingale
       case mart: if (OrdersHistoryTotal()!=0) mlots=NormalizeDouble(blots*(MathPow(cator,(LossCount))),2); else mlots = blots; break;
       
    //Reversed Martingale
       case r_mart: if (OrdersHistoryTotal()!=0) mlots=NormalizeDouble(blots*(MathPow(cator,(WinCount))),2); else mlots = blots; break;
       
    //Scale after loss (Fixed)
       case scale: if (OrdersHistoryTotal()!=0) mlots=blots+(f_inc*WinCount); else mlots = blots; break;
       
    //Scale after win (Fixed)
       case r_scale: if (OrdersHistoryTotal()!=0) mlots=blots+(f_inc*LossCount); else mlots = blots; break;
       
    //Classic
       case classic: mlots = blots; break;
  };
  return mlots;
}

void calculateStopLoss(string name, double &SLp, double &TPp, double &TSp){

  double pt = MarketInfo (name, MODE_POINT);
  double spread = MarketInfo(name, MODE_SPREAD) * pt;

  
  //--- Max DD calculation
  //--- ATR for Sl / HiLo MA for SL
  int atrTf = atr_tf;
  double atr1 = iATR(name,atrTf,atr_p,0);// Period 15
  double atr2 = iATR(name,atrTf,2*atr_p,0);// Period 30
  double atr3 = NormalizeDouble(((atr1+atr2)/2)*atr_x,MarketInfo (name, MODE_DIGITS));// Atr weight 1 in SL?TP/TSL
  
  double ma1 = iMA(name,atrTf,atr_p*2,0,MODE_LWMA,PRICE_HIGH,0);// 30 MA High
  double ma2 = iMA(name,atrTf,atr_p*2,0,MODE_LWMA,PRICE_LOW,0);// 30 Ma Low
  double ma3 = NormalizeDouble(hilo_x*(ma1 - ma2),MarketInfo (name, MODE_DIGITS));// HiLo weight 0.5 in SL/TP/TSL

  //--- SL & TP calculation 
  double sl_p1 = NormalizeDouble(pt*sl_p/((1/(Close[0]+(spread/2)))),MarketInfo (name, MODE_DIGITS));
  SLp = sl_p1 + atr3 + ma3;// (atr15+atr30)/2 + (ma30High-ma30Low)/2
  TPp = NormalizeDouble(pf*(SLp),MarketInfo (name, MODE_DIGITS)); // 3.5 SLP
  TSp = NormalizeDouble(tf*(SLp),MarketInfo (name, MODE_DIGITS)); //0.8 SLP

}
//+------------------------------------------------------------------+
bool VerifySymbol(string &list[],string yoursymbol)
  {
   for(int i=0;i<ArraySize(list);i++)
     {
      if(yoursymbol==list[i])
        {
         return(true);
        }
     }
   return(false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Assign28SymbolToList(string &array[])
  {
//EURUSD
//GBPUSD
//AUDUSD
//NZDUSD
//USDCAD
//USDJPY
//USDCHF
   array[0]="EURUSD";
   array[1]="GBPUSD";
   array[2]="AUDUSD";
   array[3]="NZDUSD";
   array[4]="USDCAD";
   array[5]="USDJPY";
   array[6]="USDCHF";
//EURGBP
//EURAUD
//EURNZD
//EURCAD
//EURJPY
//EURCHF
   array[7]="EURGBP";
   array[8]="EURAUD";
   array[9]="EURNZD";
   array[10]="EURCAD";
   array[11]="EURJPY";
   array[12]="EURCHF";
//GBPAUD
//GBPNZD
//GBPCAD
//GBPJPY
//GBPCHF
   array[13]="GBPAUD";
   array[14]="GBPNZD";
   array[15]="GBPCAD";
   array[16]="GBPJPY";
   array[17]="GBPCHF";

//AUDNZD
//AUDCAD
//AUDJPY
//AUDCHF
   array[18]="AUDNZD";
   array[19]="AUDCAD";
   array[20]="AUDJPY";
   array[21]="AUDCHF";
//NZDCAD
//NZDJPY
//NZDCHF
   array[22]="NZDCAD";
   array[23]="NZDJPY";
   array[24]="NZDCHF";
//CHFJPY
//CADCHF
//CADJPY
   array[25]="CHFJPY";
   array[26]="CADCHF";
   array[27]="CADJPY";
  }
//+------------------------------------------------------------------+
//----------------------------------------------------------------------------

double sqHeikenAshi(string symbol, int timeframe, string mode) {
   if(symbol == "NULL") {
      if(mode == "Open") {
         return(iCustom(NULL, 0, "Heiken Ashi", 0,0,0,0, 2, shift));
      }
      if(mode == "Close") {
         return(iCustom(NULL, 0, "Heiken Ashi", 0,0,0,0, 3, shift));
      }
      if(mode == "High") {
         return(MathMax(iCustom( NULL, 0, "Heiken Ashi", 0,0,0,0, 0, shift), iCustom( NULL, 0, "Heiken Ashi", 0,0,0,0, 1, shift)));
      }
      if(mode == "Low") {
         return(MathMin(iCustom( NULL, 0, "Heiken Ashi", 0,0,0,0, 0, shift), iCustom( NULL, 0, "Heiken Ashi", 0,0,0,0, 1, shift)));
      }

   } else {
      if(mode == "Open") {
         return(iCustom( symbol, timeframe, "Heiken Ashi", 0,0,0,0, 2, shift));
      }
      if(mode == "Close") {
         return(iCustom( symbol, timeframe, "Heiken Ashi", 0,0,0,0, 3, shift));
      }
      if(mode == "High") {
         return(MathMax(iCustom( symbol, timeframe, "Heiken Ashi", 0,0,0,0, 0, shift), iCustom( symbol, timeframe, "Heiken Ashi", 0,0,0,0, 1, shift)));
      }
      if(mode == "Low") {
         return(MathMin(iCustom( symbol, timeframe, "Heiken Ashi", 0,0,0,0, 0, shift), iCustom( symbol, timeframe, "Heiken Ashi", 0,0,0,0, 1, shift)));
      }
   }

   return(-1);
}

/*       ________________________________________________
         T                                              T
         T                WRITE ON CHART                T
         T______________________________________________T
*/

//--- stats
int getLastOrderOpenTime(string name){
  int result=0;
  for(int i=0;i<OrdersTotal();i++)
  {
     OrderSelect(i,SELECT_BY_POS ,MODE_TRADES);
     if (OrderMagicNumber()==MagicNumber && OrderSymbol()==name) result = OrderOpenTime();
   }
  return (result);
}

int sqGetBarsFromOrderOpen(int opTime) {
   if(opTime == 0){
     return 0;
   }
   datetime currentTime = TimeCurrent();
   int numberOfBars = 0;
   for(int i=0; i<1000; i++) {
      if(opTime < Time[i]) {
         numberOfBars++;
      }
   }
   return(numberOfBars);
}

double Earnings(int shift) {
   double aggregated_profit = 0;
   for (int position = 0; position < OrdersHistoryTotal(); position++) {
      if (!(OrderSelect(position, SELECT_BY_POS, MODE_HISTORY))) break;
      if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         if (OrderCloseTime() >= iTime(Symbol(), PERIOD_D1, shift) && OrderCloseTime() < iTime(Symbol(), PERIOD_D1, shift) + 86400) aggregated_profit = aggregated_profit + OrderProfit() + OrderCommission() + OrderSwap();
   }
   return (aggregated_profit);
}

//--- Key can either be total_win, total_loss, total_profit, total_volume!

double Counta (int key, string name=NULL){

   double count_tot = 0;
   double balance = AccountBalance();
   double equity = AccountEquity();
   double drawdown = 0;
   double profit = 0;
   double lots = 0;
   double runup = 0;
   
   switch (key) {
   
   //All time wins counter
   case(1):
     for (int i = 0; i < OrdersHistoryTotal(); i++) 
    {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) 
        continue;
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol() && OrderProfit()>0) //total number of loss
        {count_tot++;}
     }
   break;

   //All time loss counter
   case(2):
     for (int i = 0; i < OrdersHistoryTotal(); i++) 
    {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) 
        continue;
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol() && OrderProfit()<0) //total number of loss
        {count_tot++;}
     }
   break;
   
   //All time profit
   case(3):
     for (int i = 0; i < OrdersHistoryTotal(); i++) 
    {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) 
        continue;
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()) //total profit
        {profit = profit + OrderProfit() + OrderCommission() + OrderSwap();}
     }
     count_tot = profit;
   break;

   //All time lots
   case(4):
     for (int i = 0; i < OrdersHistoryTotal(); i++) 
    {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) 
        continue;
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()) //total profit
        {lots = lots + OrderLots();}
     }
     count_tot = lots;
   break;
   
   //Chain Loss
   case(5):
     for (int i = 0; i < OrdersHistoryTotal(); i++) 
    {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) 
        continue;
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == name && OrderProfit()<0) 
        {count_tot++;}
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == name && OrderProfit()>0)
          {count_tot=0;}
     }
   break;
   
   //Chain Win
   case(6):
     for (int i = 0; i < OrdersHistoryTotal(); i++) 
    {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) 
        continue;
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == name && OrderProfit()<0) 
        {count_tot=0;}
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == name && OrderProfit()>0)
          {count_tot++;}
     }
   break;
   
   //Chart Drawdown %
   case(7):
     for (int i = 0; i < OrdersTotal(); i++) 
    {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) 
        continue;
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()) //current profit
        { profit = profit + OrderProfit() + OrderCommission() + OrderSwap();}
     }
     if (profit>0) drawdown = 0; else drawdown = NormalizeDouble( (profit/balance)*100,2 );
     count_tot = drawdown;
   break;
   
   //Acc Drawdown %
   case(8):
      if (equity >= balance) drawdown = 0; else drawdown = NormalizeDouble( ((equity-balance)*100) / balance,2 );
      count_tot = drawdown;
   break;

   //Chart dd money
   case(9):
     for (int i = 0; i < OrdersTotal(); i++) 
    {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) 
        continue;
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()) //current profit
        { profit = profit + OrderProfit() + OrderCommission() + OrderSwap();}
     }
     if (profit >= 0) drawdown = 0; else drawdown = profit;
     count_tot = drawdown;
   break; 

   //Acc dd money
   case(10):
     if (equity >= balance) drawdown = 0; else drawdown = equity - balance;
     count_tot = drawdown;
   break; 
   
   //Chart Runup %
   case(11):
     for (int i = 0; i < OrdersTotal(); i++) 
    {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) 
        continue;
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()) //current profit
        { profit = profit + OrderProfit() + OrderCommission() + OrderSwap();}
     }
     if (profit<0) runup = 0; else runup = NormalizeDouble( (profit/balance)*100,2 );
     count_tot = runup;
   break;
   
   //Acc Runup %
   case(12):
      if (equity < balance) runup = 0; else runup = NormalizeDouble( ((equity-balance)*100) / balance,2 );
      count_tot = runup;
   break;

   //Chart runup money
   case(13):
     for (int i = 0; i < OrdersTotal(); i++) 
    {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) 
        continue;
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()) //current profit
        { profit = profit + OrderProfit() + OrderCommission() + OrderSwap();}
     }
     if (profit < 0) runup = 0; else runup = profit;
     count_tot = runup;
   break; 

   //Acc runup money
   case(14):
     if (equity < balance) runup = 0; else runup = equity - balance;
     count_tot = runup;
   break;
   
   //Current profit here
   case(15):
     for (int i = 0; i < OrdersTotal(); i++) 
    {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) 
        continue;
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()) //current profit
        {profit = profit + OrderProfit() + OrderCommission() + OrderSwap();}
     }
     count_tot = profit;
   break;
   
   //Current profit acc
   case(16):
      count_tot = AccountProfit();
   break;

   //Gross profits
   case(17):
     for (int i = 0; i < OrdersHistoryTotal(); i++) 
    {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) 
        continue;
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol() && OrderProfit()>0)
        {profit = profit + OrderProfit() + OrderCommission() + OrderSwap();}
     }
     count_tot = profit;
   break;

   //Gross loss
   case(18):
     for (int i = 0; i < OrdersHistoryTotal(); i++) 
    {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) 
        continue;
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol() && OrderProfit()<0) //total profit
        {profit = profit + OrderProfit() + OrderCommission() + OrderSwap();}
     }
     count_tot = profit;
   break;

 }
 return(count_tot);
 
}

//--- Order Counter to enter only when result = 0

int TotalOrdersCount(string name=NULL)
{
  int result=0;
  for(int i=0;i<OrdersTotal();i++)
  {
     OrderSelect(i,SELECT_BY_POS ,MODE_TRADES);
     if (OrderMagicNumber()==MagicNumber && (name==NULL || OrderSymbol()==name)) result++;
   }
  return (result);
}

//--- Write stuff

//--- HUD Rectangle
void HUD()
  {
  ObjectCreate(ChartID(),"HUD",OBJ_RECTANGLE_LABEL,0,0,0);
//--- set label coordinates
   ObjectSetInteger(ChartID(),"HUD",OBJPROP_XDISTANCE,290);
   ObjectSetInteger(ChartID(),"HUD",OBJPROP_YDISTANCE,28);
//--- set label size
   ObjectSetInteger(ChartID(),"HUD",OBJPROP_XSIZE,185);
   ObjectSetInteger(ChartID(),"HUD",OBJPROP_YSIZE,510);
//--- set background color
   ObjectSetInteger(ChartID(),"HUD",OBJPROP_BGCOLOR,clrBlack);
//--- set border type
   ObjectSetInteger(ChartID(),"HUD",OBJPROP_BORDER_TYPE,BORDER_FLAT);
//--- set the chart's corner, relative to which point coordinates are defined
   ObjectSetInteger(ChartID(),"HUD",OBJPROP_CORNER,CORNER_RIGHT_UPPER);
//--- set flat border color (in Flat mode)
   ObjectSetInteger(ChartID(),"HUD",OBJPROP_COLOR,clrWhite);
//--- set flat border line style
   ObjectSetInteger(ChartID(),"HUD",OBJPROP_STYLE,STYLE_SOLID);
//--- set flat border width
   ObjectSetInteger(ChartID(),"HUD",OBJPROP_WIDTH,1);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(ChartID(),"HUD",OBJPROP_BACK,false);
//--- enable (true) or disable (false) the mode of moving the label by mouse
   ObjectSetInteger(ChartID(),"HUD",OBJPROP_SELECTABLE,false);
   ObjectSetInteger(ChartID(),"HUD",OBJPROP_SELECTED,false);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(ChartID(),"HUD",OBJPROP_HIDDEN,true);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(ChartID(),"HUD",OBJPROP_ZORDER,0);
}

// void drawInfo(){
//    string label_name ="displaySignal";
//    if(ObjectFind(label_name)<0) 
//      { 
//       //--- create Label object 
//       ObjectCreate(0,label_name,OBJ_RECTANGLE_LABEL,0,0,0);            
//       //--- set X coordinate 
//       ObjectSetInteger(0,label_name,OBJPROP_XDISTANCE,1); 
//       //--- set Y coordinate 
//       ObjectSetInteger(0,label_name,OBJPROP_YDISTANCE,15);
//       //--- set X size 
//       ObjectSetInteger(0,label_name,OBJPROP_XSIZE,125); 
//       //--- set Y size 
//       ObjectSetInteger(0,label_name,OBJPROP_YSIZE,535);
//       //--- define background color 
//       ObjectSetInteger(0,label_name,OBJPROP_BGCOLOR,clrDarkBlue); 
//       //--- define text for object Label 
//       ObjectSetString(0,label_name,OBJPROP_TEXT,"Cache");    
//       //--- disable for mouse selecting 
//       ObjectSetInteger(0,label_name,OBJPROP_SELECTABLE,0);
//       //--- set the style of rectangle lines 
//       ObjectSetInteger(0,label_name,OBJPROP_STYLE,STYLE_SOLID);
//       //--- define border type 
//       ObjectSetInteger(0,label_name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
//       //--- define border width 
//       ObjectSetInteger(0,label_name,OBJPROP_WIDTH,1); 
//       //--- draw it on the chart 
//       ChartRedraw(0);
//      }
// }

void Earnings() {

   int total_wins = Counta(1);
   int total_loss = Counta(2);   
   int total_trades = total_wins + total_loss;
   
   double total_profit = Counta(3);
   double total_volumes = Counta(4);
   int chain_loss = Counta(5);
   int chain_win = Counta(6);
   
   double chart_dd_pc = Counta(7);
   double acc_dd_pc = Counta(8);
   double chart_dd = Counta(9);
   double acc_dd = Counta(10);
   
   double chart_runup_pc = Counta(11);
   double acc_runup_pc = Counta(12);
   double chart_runup = Counta(13);
   double acc_runup = Counta(14);   
   
   double chart_profit = Counta(15);
   double acc_profit = Counta(16);

   double gross_profits= Counta(17);
   double gross_loss = Counta(18);
   
   //pnl vs profit factor
   double profit_factor;
   if (gross_loss!=0 && gross_profits!=0) profit_factor = NormalizeDouble(gross_profits/MathAbs(gross_loss),2);

   //Total volumes vs Average
   double av_volumes;
   if (total_volumes!=0 && total_trades!=0) av_volumes = NormalizeDouble(total_volumes/total_trades,2);

   //Total trades vs winrate
   int winrate;
   if (total_trades!=0) winrate = (total_wins*100/total_trades);

   //Relative DD vs Max DD %
   if (chart_dd_pc < max_dd_pc) max_dd_pc = chart_dd_pc;
   if (acc_dd_pc < max_acc_dd_pc) max_acc_dd_pc = acc_dd_pc;
   //Relative DD vs Max DD $$
   if (chart_dd < max_dd) max_dd = chart_dd;
   if (acc_dd < max_acc_dd) max_acc_dd = acc_dd;

   //Relative runup vs Max runup %
   if (chart_runup_pc > max_runup_pc) max_runup_pc = chart_runup_pc;
   if (acc_runup_pc > max_acc_runup_pc) max_acc_runup_pc = acc_runup_pc;
   //Relative runup vs Max runup $$
   if (chart_runup > max_runup) max_runup = chart_runup;
   if (acc_runup > max_acc_runup) max_acc_runup = acc_runup;
   
   //Spread vs Maxspread
   if (MarketInfo(Symbol(), MODE_SPREAD) > spread) spread = MarketInfo(Symbol(), MODE_SPREAD);
   
   //Chains vs Max chains
   if (chain_loss > max_chain_loss) max_chain_loss = chain_loss;
   if (chain_win > max_chain_win) max_chain_win = chain_win; 
 
//--- Currency crypt

   string curr = "none";

   if (AccountCurrency() == "USD") curr = "$";
   if (AccountCurrency() == "JPY") curr = "¥";
   if (AccountCurrency() == "EUR") curr = "€";
   if (AccountCurrency() == "GBP") curr = "£";
   if (AccountCurrency() == "CHF") curr = "CHF";
   if (AccountCurrency() == "AUD") curr = "A$";
   if (AccountCurrency() == "CAD") curr = "C$";
   if (AccountCurrency() == "RUB") curr = "руб";
   
   if (curr == "none") curr = AccountCurrency();

//--- Equity / balance / floating

   string txt1, content;
   int content_len=StringLen(content);
   
   txt1 = version + "50";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 10);
   }
   ObjectSetText(txt1, "_______________________________", 10, "Century Gothic", color1);
   
   txt1 = version + "51";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 116);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 29);
   }
   ObjectSetText(txt1, "Portfolio", 9, "Century Gothic", color1);

   txt1 = version + "52";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 34);
   }
   ObjectSetText(txt1, "_______________________________", 10, "Century Gothic", color1);

   txt1 = version + "100";
   if(AccountEquity() >= AccountBalance()){
         if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 1);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 52);
         }
   
         if(chart_profit==0) ObjectSetText(txt1, "Equity : " + DoubleToStr(AccountEquity(), 2) + curr, 16, "Century Gothic", color3);
         if(chart_profit!=0) ObjectSetText(txt1, "Equity : " + DoubleToStr(AccountEquity(), 2) + curr, 11, "Century Gothic", color3);
   }
   if(AccountEquity() < AccountBalance()){
         if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 1);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 52);
         }
         if(chart_profit==0) ObjectSetText(txt1, "Equity : " + DoubleToStr(AccountEquity(), 2) + curr, 16, "Century Gothic", color4);
         if(chart_profit!=0) ObjectSetText(txt1, "Equity : " + DoubleToStr(AccountEquity(), 2) + curr, 11, "Century Gothic", color4);
   }

   txt1 = version + "101";
   if(chart_profit>0){
      if (ObjectFind(txt1) == -1) {
         ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
         ObjectSet(txt1, OBJPROP_CORNER, 1);
         ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
         ObjectSet(txt1, OBJPROP_YDISTANCE, 70);
      }
      ObjectSetText(txt1, "Floating chart P&L : +" + DoubleToStr(chart_profit,2) + curr, 9, "Century Gothic", color3);
   }
   if(chart_profit<0){
      if (ObjectFind(txt1) == -1) {
         ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
         ObjectSet(txt1, OBJPROP_CORNER, 1);
         ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
         ObjectSet(txt1, OBJPROP_YDISTANCE, 70);
      }
      ObjectSetText(txt1, "Floating chart P&L : " + DoubleToStr(chart_profit,2) + curr, 9, "Century Gothic", color4);
   }
   if(OrdersTotal()==0) ObjectDelete(txt1);

   txt1 = version + "102";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      if(TotalOrdersCount()==0) ObjectSet(txt1, OBJPROP_YDISTANCE, 87);
      if(TotalOrdersCount()!=0) ObjectSet(txt1, OBJPROP_YDISTANCE, 87);
   }
   if(TotalOrdersCount()==0) ObjectSetText(txt1, "Balance : " + DoubleToStr(AccountBalance(), 2) + curr, 9, "Century Gothic", color2);
   if(TotalOrdersCount()!=0) ObjectSetText(txt1, "Balance : " + DoubleToStr(AccountBalance(), 2) + curr, 9, "Century Gothic", color2);
   
//--- Analytics

   txt1 = version + "53";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 91);
   }
   ObjectSetText(txt1, "_______________________________", 10, "Century Gothic", color1);

   txt1 = version + "54";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 116);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 110);
   }
   ObjectSetText(txt1, "Analytics", 9, "Century Gothic", color1);

   txt1 = version + "55";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 115);
   }
   ObjectSetText(txt1, "_______________________________", 10, "Century Gothic", color1);

   txt1 = version + "200";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 135);
   }
   if(chart_runup >= 0){
      ObjectSetText(txt1, "Chart runup : " + DoubleToString(chart_runup_pc, 2) + "% [" + DoubleToString(chart_runup, 2) + curr + "]", 8, "Century Gothic", color3);
   }
   if(chart_dd < 0) {
      ObjectSetText(txt1, "Chart drawdown : " + DoubleToString(chart_dd_pc, 2) + "% [" + DoubleToString(chart_dd, 2) + curr + "]", 8, "Century Gothic", color4);
   }
   
   txt1 = version + "201";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 147);
   }
   if(acc_runup >= 0){
      ObjectSetText(txt1, "Acc runup : " + DoubleToString(acc_runup_pc, 2) + "% [" + DoubleToString(acc_runup, 2) + curr + "]" , 8, "Century Gothic", color3);
   }
   if(acc_dd < 0){
      ObjectSetText(txt1, "Acc DD : " + DoubleToString(acc_dd_pc, 2) + "% [" + DoubleToString(acc_dd, 2) + curr + "]" , 8, "Century Gothic", color4);
   }

   txt1 = version + "202";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 159);
   }
   ObjectSetText(txt1, "Max chart runup : " + DoubleToString(max_runup_pc, 2) + "% [" + DoubleToString(max_runup,2) + curr + "]", 8, "Century Gothic", color2);

   txt1 = version + "203";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 171);
   }
   ObjectSetText(txt1, "Max chart drawdon : " + DoubleToString(max_dd_pc, 2) + "% [" + DoubleToString(max_dd,2) + curr + "]", 8, "Century Gothic", color2);

   txt1 = version + "204";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 183);
   }
   ObjectSetText(txt1, "Max acc runup : " + DoubleToString(max_acc_runup_pc, 2) + "% [" + DoubleToString(max_acc_runup,2) + curr + "]", 8, "Century Gothic", color2);

   txt1 = version + "205";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 195);
   }
   ObjectSetText(txt1, "Max acc drawdown : " + DoubleToString(max_acc_dd_pc, 2) + "% [" + DoubleToString(max_acc_dd,2) + curr + "]", 8, "Century Gothic", color2);

   txt1 = version + "206";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 207);
   }
   ObjectSetText(txt1, "Trades won : " + IntegerToString(total_wins, 0) + " II Trades lost : " + IntegerToString(total_loss, 0) + " [" + DoubleToString(winrate,0) + "% winrate]", 8, "Century Gothic", color2);

   txt1 = version + "207";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 219);
   }
   ObjectSetText(txt1, "W-Chain : " + IntegerToString(chain_win, 0) + " [Max : " + IntegerToString(max_chain_win,0) + "] II L-Chain : " + IntegerToString(chain_loss, 0) + " [Max : " + IntegerToString(max_chain_loss,0) + "]", 8, "Century Gothic", color2);

   txt1 = version + "208";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 231);
   }
   ObjectSetText(txt1, "Overall volume traded : " + DoubleToString(total_volumes, 2) + " lots", 8, "Century Gothic", color2);

   txt1 = version + "209";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 243);
   }
   ObjectSetText(txt1, "Average volume /trade : " + DoubleToString(av_volumes, 2) + " lots", 8, "Century Gothic", color2);

   txt1 = version + "210";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 255);
   }
   string expectancy;
   if(total_trades!=0) expectancy = DoubleToStr(total_profit/total_trades, 2);
   
   if(total_trades!=0 && total_profit/total_trades > 0){
      ObjectSetText(txt1, "Payoff expectancy /trade : " + expectancy + curr, 8, "Century Gothic", color3);
   }
   if(total_trades!=0 && total_profit/total_trades < 0){
      ObjectSetText(txt1, "Payoff expectancy /trade : " + expectancy + curr, 8, "Century Gothic", color4);
   }
   if(total_trades==0){
      ObjectSetText(txt1, "Payoff expectancy /trade : NA", 8, "Century Gothic", color3);
   }

   txt1 = version + "211";
   if(total_trades !=0 && profit_factor >= 1){
      if (ObjectFind(txt1) == -1) {
         ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
         ObjectSet(txt1, OBJPROP_CORNER, 1);
         ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
         ObjectSet(txt1, OBJPROP_YDISTANCE, 267);
      }
      ObjectSetText(txt1, "Profit factor : " + DoubleToString(profit_factor, 2), 8, "Century Gothic", color3);
   }
   if(total_trades !=0 && profit_factor < 1){
      if (ObjectFind(txt1) == -1) {
         ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
         ObjectSet(txt1, OBJPROP_CORNER, 1);
         ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
         ObjectSet(txt1, OBJPROP_YDISTANCE, 267);
      }
      ObjectSetText(txt1, "Profit factor : " + DoubleToString(profit_factor, 2), 8, "Century Gothic", color4);
   }
   if(total_trades == 0){
      if (ObjectFind(txt1) == -1) {
         ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
         ObjectSet(txt1, OBJPROP_CORNER, 1);
         ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
         ObjectSet(txt1, OBJPROP_YDISTANCE, 267);
      }
      ObjectSetText(txt1, "Profit factor : NA", 8, "Century Gothic", color3);
   }  
//--- Earnings

   txt1 = version + "56";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 270);
   }
   ObjectSetText(txt1, "_______________________________", 10, "Century Gothic", color1);

   txt1 = version + "57";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 116);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 289);
   }
   ObjectSetText(txt1, "Earnings", 9, "Century Gothic", color1);

   txt1 = version + "58";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 295);
   }
   ObjectSetText(txt1, "_______________________________", 10, "Century Gothic", color1);
   
   double profitx = Earnings(0);
   txt1 = version + "300";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 315);
   }
   ObjectSetText(txt1, "Earnings today : " + DoubleToStr(profitx, 2) + curr, 8, "Century Gothic", color2);

   profitx = Earnings(1);
   txt1 = version + "301";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 327);
   }
   ObjectSetText(txt1, "Earnings yesterday : " + DoubleToStr(profitx, 2) + curr, 8, "Century Gothic", color2);

   profitx = Earnings(2);
   txt1 = version + "302";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 339);
   }
   ObjectSetText(txt1, "Earnings before yesterday : " + DoubleToStr(profitx, 2) + curr, 8, "Century Gothic", color2);

   txt1 = version + "303";
   if(total_profit >= 0){
      if (ObjectFind(txt1) == -1) {
         ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
         ObjectSet(txt1, OBJPROP_CORNER, 1);
         ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
         ObjectSet(txt1, OBJPROP_YDISTANCE, 351);
      }
      ObjectSetText(txt1, "All time profit : " + DoubleToString(total_profit, 2) + curr, 8, "Century Gothic", color3);
   }
   if(total_profit < 0){
      if (ObjectFind(txt1) == -1) {
         ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
         ObjectSet(txt1, OBJPROP_CORNER, 1);
         ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
         ObjectSet(txt1, OBJPROP_YDISTANCE, 351);
      }
      ObjectSetText(txt1, "All time loss : " + DoubleToString(total_profit, 2) + curr, 8, "Century Gothic", color4);
   }

//--- Broker & Account

   txt1 = version + "59";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 354);
   }
   ObjectSetText(txt1, "_______________________________", 10, "Century Gothic", color1);

   txt1 = version + "60";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 81);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 373);
   }
   ObjectSetText(txt1, "Broker Information", 9, "Century Gothic", color1);

   txt1 = version + "61";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 378);
   }
   ObjectSetText(txt1, "_______________________________", 10, "Century Gothic", color1);
   
   txt1 = version + "400";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 398);
   }
   ObjectSetText(txt1, "Spread : " + DoubleToString(MarketInfo(Symbol(), MODE_SPREAD), 0) + " pts [Max : " + DoubleToString(spread, 0) + " pts]", 8, "Century Gothic", color2);

   txt1 = version + "401";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 410);
   }
   ObjectSetText(txt1, "ID : " + AccountCompany(), 8, "Century Gothic", color2);

   txt1 = version + "402";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 422);
   }
   ObjectSetText(txt1, "Server : " + AccountServer(), 8, "Century Gothic", color2);

   txt1 = version + "403";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 434);
   }
   ObjectSetText(txt1, "Freeze lvl : " + IntegerToString(MarketInfo(Symbol(), MODE_FREEZELEVEL), 0) + " pts II Stop lvl : " + IntegerToString(MarketInfo(Symbol(), MODE_STOPLEVEL), 0) + " pts", 8, "Century Gothic", color2);

   txt1 = version + "404";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 446);
   }
   ObjectSetText(txt1, "L-Swap : " + DoubleToStr(MarketInfo(Symbol(), MODE_SWAPLONG), 2) + curr + "/lot II S-Swap : " + DoubleToStr(MarketInfo(Symbol(), MODE_SWAPSHORT), 2) + curr + "/lot", 8, "Century Gothic", color2);

   txt1 = version + "62";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 449);
   }
   ObjectSetText(txt1, "_______________________________", 10, "Century Gothic", color1);

   txt1 = version + "63";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 116);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 468);
   }
   ObjectSetText(txt1, "Account", 9, "Century Gothic", color1);

   txt1 = version + "64";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 473);
   }
   ObjectSetText(txt1, "_______________________________",  10, "Century Gothic", color1);

   txt1 = version + "500";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 493);
   }
   ObjectSetText(txt1, "ID : " + AccountName() + " [#" + IntegerToString(AccountNumber(),0) + "]", 8, "Century Gothic", color2);

   txt1 = version + "501";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 505);
   }
   ObjectSetText(txt1, "Leverage : " + AccountLeverage() + ":1", 8, "Century Gothic", color2);

   txt1 = version + "502";
   if (ObjectFind(txt1) == -1) {
      ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt1, OBJPROP_CORNER, 1);
      ObjectSet(txt1, OBJPROP_XDISTANCE, 10);
      ObjectSet(txt1, OBJPROP_YDISTANCE, 517);
   }
   ObjectSetText(txt1, "Currency : " + AccountCurrency() + " [" + curr + "]", 8, "Century Gothic", color2);
}

//--- Write EA's Name

void Popup() {
   string txt2 = version + "20";
   if (ObjectFind(txt2) == -1) {
      ObjectCreate(txt2, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt2, OBJPROP_CORNER, 0);
      ObjectSet(txt2, OBJPROP_XDISTANCE, 402);
      ObjectSet(txt2, OBJPROP_YDISTANCE, 4);
   }
   ObjectSetText(txt2, "ADX Bone122",25, "Century Gothic", color1);
   
   txt2 = version + "21";
   if (ObjectFind(txt2) == -1) {
      ObjectCreate(txt2, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt2, OBJPROP_CORNER, 0);
      ObjectSet(txt2, OBJPROP_XDISTANCE, 432);
      ObjectSet(txt2, OBJPROP_YDISTANCE, 49);
   }
   ObjectSetText(txt2, "by Edorenta || version " + version, 8, "Arial", Gray);
   
   txt2 = version + "22";
   if (ObjectFind(txt2) == -1) {
      ObjectCreate(txt2, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt2, OBJPROP_CORNER, 0);
      ObjectSet(txt2, OBJPROP_XDISTANCE, 398);
      ObjectSet(txt2, OBJPROP_YDISTANCE, 35);
   }
   ObjectSetText(txt2, "______________________________", 8, "Arial", Gray);
   
   txt2 = version + "23";
   if (ObjectFind(txt2) == -1) {
      ObjectCreate(txt2, OBJ_LABEL, 0, 0, 0);
      ObjectSet(txt2, OBJPROP_CORNER, 0);
      ObjectSet(txt2, OBJPROP_XDISTANCE, 398);
      ObjectSet(txt2, OBJPROP_YDISTANCE, 50);
   }
   ObjectSetText(txt2, "______________________________", 8, "Arial", Gray);
}

/*       ________________________________________________
         T                                              T
         T              BYE BYE /terminate              T
         T______________________________________________T

*/

string strPeriod( int intPeriod )
{
  switch ( intPeriod )
  {
    case PERIOD_MN1: return("Monthly");
    case PERIOD_W1:  return("Weekly");
    case PERIOD_D1:  return("Daily");
    case PERIOD_H4:  return("H4");
    case PERIOD_H1:  return("H1");
    case PERIOD_M30: return("M30");
    case PERIOD_M15: return("M15");
    case PERIOD_M5:  return("M5");
    case PERIOD_M1:  return("M1");
    case PERIOD_M2:  return("M2");
    case PERIOD_M3:  return("M3");
    case PERIOD_M4:  return("M4");
    case PERIOD_M6:  return("M6");
    case PERIOD_M12:  return("M12");
    case PERIOD_M10:  return("M10");
    default:     return("Offline");
  }
}
void log(string String)
{
   
   int Handle;
   string key = "ThreeScreen";
   //if (!Auditing) return;
   string Filename = "logs\\" + key + " (" + Symbol() + ", " + strPeriod( Period() ) + 
              ")\\" + TimeToStr( LocalTime(), TIME_DATE ) + ".txt";
              
   Handle = FileOpen(Filename, FILE_READ|FILE_WRITE|FILE_CSV, "/t");
   if (Handle < 1)
   {
      Print("Error opening audit file: Code ", GetLastError());
      return;
   }

   if (!FileSeek(Handle, 0, SEEK_END))
   {
      Print("Error seeking end of audit file: Code ", GetLastError());
      return;
   }

   if (FileWrite(Handle, TimeToStr(CurTime(), TIME_DATE|TIME_SECONDS) + "  " + String) < 1)
   {
      Print("Error writing to audit file: Code ", GetLastError());
      return;
   }

   FileClose(Handle);
}