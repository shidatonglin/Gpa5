//+------------------------------------------------------------------+
//|                                                 IchomuSignal.mqh |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

#include <Indicators\Oscilators.mqh>
#include <Indicators\Trend.mqh>
#include <Trade\SymbolInfo.mqh>

enum SIGNAL_DIRECTION{
   DIRECTION_BUY  =  1,
   DIRECTION_SELL = -1,
   DIRECTION_NONE =  0
};

class CSignal{

   private:
   
   protected:
   
      int               m_handle;
      CSymbolInfo       m_symbol;
      ENUM_TIMEFRAMES   m_period;
      
   public:
      CSignal(void);
      CSignal(CSymbolInfo & symbol, ENUM_TIMEFRAMES period);
      ~CSignal(void);
      void SetPeriod(ENUM_TIMEFRAMES period)                   {m_period=period;}
      void SetSymbol(CSymbolInfo &symbol)                      {m_symbol=symbol;}
      int  GetHandle(void)                                     {return m_handle;}
      virtual bool InitSignal(void);
      virtual SIGNAL_DIRECTION getMainValueSignal(int ind);
      virtual SIGNAL_DIRECTION getCrossSignal(int ind);
};

CSignal :: CSignal(void) : m_handle(INVALID_HANDLE),
                           m_period(PERIOD_CURRENT){
   m_symbol.Name(Symbol());
}

CSignal :: CSignal(CSymbolInfo &symbol, ENUM_TIMEFRAMES period){
   m_symbol = symbol;
   m_period = period;
   if(m_symbol.Name()=="") m_symbol.Name(Symbol());
}

CSignal :: ~CSignal(void) {
   if(m_handle!=INVALID_HANDLE){
      IndicatorRelease(m_handle);
      m_handle=INVALID_HANDLE;
   }
}


class CMACD : public CSignal {

protected:
   CiMACD             m_MACD;           // object-oscillator
   
   //--- adjusted parameters
   int                m_period_fast;    // the "period of fast EMA" parameter of the oscillator
   int                m_period_slow;    // the "period of slow EMA" parameter of the oscillator
   int                m_period_signal;  // the "period of averaging of difference" parameter of the oscillator
   ENUM_APPLIED_PRICE m_applied;       // the "price series" parameter of the oscillator
   
public:
                     CMACD(void);
                    ~CMACD(void);
   //--- method of verification of settings
   virtual bool      ValidationSettings(void);
   virtual bool      InitSignal(void);
   virtual SIGNAL_DIRECTION getMainValueSignal(int ind);
   virtual SIGNAL_DIRECTION getCrossSignal(int ind);
   //--- methods of setting adjustable parameters
   void              PeriodFast(int value)               { m_period_fast=value;           }
   void              PeriodSlow(int value)               { m_period_slow=value;           }
   void              PeriodSignal(int value)             { m_period_signal=value;         }
   void              Applied(ENUM_APPLIED_PRICE value)   { m_applied=value;               }
   
protected:
   //--- method of initialization of the oscillator
   bool              InitMACD();
   //--- methods of getting data
   double            Main(int ind)                     { return(m_MACD.Main(ind));      }
   double            Signal(int ind)                   { return(m_MACD.Signal(ind));    }
   double            DiffMain(int ind)                 { return(Main(ind)-Main(ind+1)); }
};

CMACD::CMACD(void) : m_period_fast(12),
                     m_period_slow(26),
                     m_period_signal(9),
                     m_applied(PRICE_CLOSE){  
   
}

CMACD :: ~CMACD(void){  }

bool CMACD :: InitSignal(){
   return InitMACD();
}

bool CMACD :: InitMACD(){ 
   //--- initialize object
   if(!m_MACD.Create(m_symbol.Name(),m_period,m_period_fast,m_period_slow,m_period_signal,m_applied))
     {
      printf(__FUNCTION__+": error initializing CiMACD object");
      return(false);
     }
   m_handle = m_MACD.Handle();
   //--- ok
   return(true);
}

SIGNAL_DIRECTION CMACD :: getCrossSignal(int ind){
   SIGNAL_DIRECTION macd_signal = DIRECTION_NONE;
   double pre_main_value = Main(ind+1);
   double pre_signal_value = Signal(ind+1);
   double main_value = Main(ind);
   double signal_value = Signal(ind);
   if(main_value>0 && main_value > signal_value && pre_main_value < pre_signal_value) macd_signal = DIRECTION_BUY;
   if(main_value<0 && main_value < signal_value && pre_main_value > pre_signal_value) macd_signal = DIRECTION_SELL;
   return macd_signal;
}

SIGNAL_DIRECTION CMACD :: getMainValueSignal(int ind){
   SIGNAL_DIRECTION macd_signal = DIRECTION_NONE;
   double main_value = Main(ind);
   double signal_value = Signal(ind);
   if(main_value > signal_value && main_value > 0) macd_signal = DIRECTION_BUY;
   if(main_value < signal_value && main_value < 0) macd_signal = DIRECTION_SELL;
   return macd_signal;
}

bool CMACD :: ValidationSettings(void){
   if(m_period_fast>=m_period_slow)
   {
      printf(__FUNCTION__+": slow period must be greater than fast period");
      return(false);
   }
   return true;
}

class CHeikenAshi : public CSignal{
   
   private:
   protected:
      CiIchimoku        m_ichimoku;
      int               m_tenkan_sen;
      int               m_kijun_sen;
      int               m_senkou_span_b;
      double            HAOpen[];
      double            HAClose[];
      double            HAHigh[];
      double            HALow[];
   public:
      CHeikenAshi(void);
      CHeikenAshi(int tenkan_sen, int kijun_sen, int senkou_spab_b) 
                              : m_tenkan_sen(tenkan_sen),
                                m_kijun_sen(kijun_sen),
                                m_senkou_span_b(senkou_spab_b){}
      ~CHeikenAshi(void);
      
      int               TenkanSenPeriod(void)        const { return(m_tenkan_sen);    }
      int               KijunSenPeriod(void)         const { return(m_kijun_sen);     }
      int               SenkouSpanBPeriod(void)      const { return(m_senkou_span_b); }
      bool              initSignal(void);
      virtual bool      InitSignal(void);
      virtual           SIGNAL_DIRECTION getMainValueSignal(int ind);
      virtual           SIGNAL_DIRECTION getCrossSignal(int ind);
};

CHeikenAshi :: CHeikenAshi(void) : m_tenkan_sen(12),
                                   m_kijun_sen(29),
                                   m_senkou_span_b(52) {
}

CHeikenAshi :: ~CHeikenAshi(void){
}

bool CHeikenAshi :: InitSignal(void){
   m_handle = iCustom(m_symbol.Name(), m_period, "Examples\\Heiken_Ashi");
   
   //if (CopyBuffer(m_handle, 0, 1, 2, HAOpen) != 2) return false;
   //if (CopyBuffer(m_handle, 3, 1, 2, HAClose) != 2) return false;
   // Don't need the previous candle for High/Low, but copying it anyway for the sake of code uniformity.
   //if (CopyBuffer(m_handle, 1, 1, 2, HAHigh) != 2) return false;
   //if (CopyBuffer(m_handle, 2, 1, 2, HALow) != 2) return false;
   if(!m_ichimoku.Create(m_symbol.Name(),m_period,m_tenkan_sen,m_kijun_sen,m_senkou_span_b)){
      printf(__FUNCTION__+": error initializing Ichimoku object");
      return(false);
   }
   if(m_handle == INVALID_HANDLE) return false;
   return true;
}

SIGNAL_DIRECTION CHeikenAshi :: getMainValueSignal(int ind){
   SIGNAL_DIRECTION ichomuTrendLowTF = DIRECTION_NONE;
   double IchomuC = m_ichimoku.SenkouSpanA(ind);
   double IchomuD = m_ichimoku.SenkouSpanB(ind);
   // HA close value
   if (CopyBuffer(m_handle, 3, ind, 2, HAClose) != 2) return ichomuTrendLowTF;
   double haClose = HAClose[0];
   
   if(haClose > MathMax(IchomuC,IchomuD)){
    ichomuTrendLowTF = DIRECTION_BUY;
   }
   
   if(haClose < MathMin(IchomuC,IchomuD)){
    ichomuTrendLowTF = DIRECTION_SELL;
   }
   return ichomuTrendLowTF;
}

SIGNAL_DIRECTION CHeikenAshi :: getCrossSignal(int ind){
   SIGNAL_DIRECTION ichomuTrendLowTF=DIRECTION_NONE;
   double IchomuC = m_ichimoku.SenkouSpanA(ind);
   double IchomuD = m_ichimoku.SenkouSpanB(ind);
// HA close value
   //double haClose=iCustom(name,Low_TF,"Heiken Ashi",0,0,0,0,3,shift);//---
   if (CopyBuffer(m_handle, 3, ind, 2, HAClose) != 2) return ichomuTrendLowTF;
   double haClose = HAClose[1];

   double pre_IchomuC = m_ichimoku.SenkouSpanA(ind+1);
   double pre_IchomuD = m_ichimoku.SenkouSpanB(ind+1);
// HA close value
   //double pre_haClose=iCustom(name,Low_TF,"Heiken Ashi",0,0,0,0,3,shift+1);
   double pre_haClose = HAClose[0];
   
   if(haClose>MathMax(IchomuC,IchomuD)
      && pre_haClose<MathMax(pre_IchomuC,pre_IchomuD))ichomuTrendLowTF=DIRECTION_BUY;

   if(haClose<MathMin(IchomuC,IchomuD)
      && pre_haClose>MathMin(pre_IchomuC,pre_IchomuD))ichomuTrendLowTF=DIRECTION_SELL;
   return ichomuTrendLowTF;
}


class CMAChannel : public CSignal{
   private:
   protected:
      CiMA                  m_high;
      CiMA                  m_low;
      double                HAClose[];
      int                   m_ma_period;
      int                   m_ma_shift;
      ENUM_MA_METHOD        m_ma_method;
      //int                   m_applied;
   public:
      CMAChannel(void);
      CMAChannel(int maPeriod,int maShift, ENUM_MA_METHOD maMethod) : m_ma_period(maPeriod),
                                                                      m_ma_shift(maShift),
                                                                      m_ma_method(maMethod) {}
      ~CMAChannel(void);
      
      void    SetMaPeriod(int value){m_ma_period=value;}
      void    SetMaShift(int value){m_ma_shift = value;}
      void    SetMaMethod(ENUM_MA_METHOD value){m_ma_method=value;}
      //void    SetApplied(int value){m_applied=value;}
      virtual bool InitSignal(void);
      virtual SIGNAL_DIRECTION getMainValueSignal(int ind);
      virtual SIGNAL_DIRECTION getCrossSignal(int ind);    
};

CMAChannel :: CMAChannel(void):m_ma_period(5)
                              ,m_ma_shift(2)
                              ,m_ma_method(MODE_SMMA){
   
}

CMAChannel :: ~CMAChannel(void){
   
}

bool CMAChannel :: InitSignal(void){
   if(!m_high.Create(m_symbol.Name(),m_period,m_ma_period,m_ma_shift,m_ma_method,PRICE_HIGH)){
      Print(__FUNCTION__ + "error initialize Machannel object");
      return false;
   }
   if(!m_low.Create(m_symbol.Name(),m_period,m_ma_period,m_ma_shift,m_ma_method,PRICE_LOW)){
      Print(__FUNCTION__ + "error initialize Machannel object");
      return false;
   }
   
   m_handle = iCustom(m_symbol.Name(), m_period, "Examples\\Heiken_Ashi");
   if(m_handle == INVALID_HANDLE) return false;
   return true;
}

SIGNAL_DIRECTION CMAChannel :: getMainValueSignal(int ind){
   SIGNAL_DIRECTION maChannelCross = 0;
   double maHigh = m_high.Main(ind);
   double maLow = m_low.Main(ind);
   if (CopyBuffer(m_handle, 3, ind, 2, HAClose) != 2) return 0;
   double haClose = HAClose[1];
   if(haClose > maHigh) maChannelCross = 1;
   if(haClose < maLow) maChannelCross = -1;
   return maChannelCross;
}

SIGNAL_DIRECTION CMAChannel :: getCrossSignal(int ind){
   SIGNAL_DIRECTION maChannelCross=0;
   double maHigh= m_high.Main(ind);
   double maLow = m_low.Main(ind);
   //double haClose=iCustom(name,Low_TF,"Heiken Ashi",0,0,0,0,3,shift);
   double pre_maHigh= m_high.Main(ind+1);
   double pre_maLow = m_low.Main(ind+1);
   //double pre_haClose=iCustom(name,Low_TF,"Heiken Ashi",0,0,0,0,3,shift+1);
   if (CopyBuffer(m_handle, 3, ind, 2, HAClose) != 2) return 0;
   double haClose=HAClose[1],pre_haClose=HAClose[0];
   
   if(haClose>maHigh && pre_haClose<pre_maHigh) maChannelCross=1;
   if(haClose<maLow  &&  pre_haClose>pre_maLow) maChannelCross=-1;
   return maChannelCross;
}

class CBbMacd : public CSignal{
   private:
   protected:
      int m_fast;
      int m_slow;
      int m_ma_period;
      int m_bars;
      int m_std;
      double  m_upper_band[];
      double  m_lower_band[];
      double  m_value[];
      double  m_direction[];
   public:
      CBbMacd(void);
      ~CBbMacd(void);
      virtual bool InitSignal(void);
      virtual SIGNAL_DIRECTION getMainValueSignal(int ind);
      virtual SIGNAL_DIRECTION getCrossSignal(int ind);    
};

CBbMacd :: CBbMacd(void):m_fast(12),
                         m_slow(26),
                         m_ma_period(10),
                         m_bars(400),
                         m_std(1){}
CBbMacd :: ~CBbMacd(void){}
bool CBbMacd :: InitSignal(void){
   m_handle = iCustom(m_symbol.Name(), m_period, "Examples\\BB_MACD", 
                      m_fast,
                      m_slow,
                      m_ma_period,
                      m_bars,
                      m_std);
   if(m_handle == INVALID_HANDLE) return false;
   return true;
}

SIGNAL_DIRECTION CBbMacd :: getMainValueSignal(int ind){
   // Buffer index start with 0
   if (CopyBuffer(m_handle, 1, ind, 2, m_direction) != 2) return 0;
   // The first element store the previous bar value
   // The second element store the current bar value
   if(m_direction[1]==0)return DIRECTION_BUY;
   if(m_direction[1]==1)return DIRECTION_SELL;
   return DIRECTION_NONE;
}

SIGNAL_DIRECTION CBbMacd :: getCrossSignal(int ind){
   SIGNAL_DIRECTION bb_macd_signal = 0;
   if (CopyBuffer(m_handle, 0, ind, 2, m_value) != 2) return 0;
   if (CopyBuffer(m_handle, 2, ind, 2, m_upper_band) != 2) return 0;
   if (CopyBuffer(m_handle, 3, ind, 2, m_lower_band) != 2) return 0;
   
   double preValue = m_value[0];
   double curValue = m_value[1];
   
   double preUpBand = m_upper_band[0];
   double preDownBand = m_lower_band[0];
   
   
   double curUpBand = m_upper_band[1];
   double curDownBand = m_lower_band[1];
   
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

class CStrategy {
   private:
   protected:
      CSignal *      m_signal;
      CMACD          m_signal_macd;
      CBbMacd        m_signal_bbmacd;
      CMAChannel     m_signal_machannel;
      CHeikenAshi    m_signal_cheikenashi;
      int            m_mode;
   public:
      CStrategy(void):m_mode(2){}
      ~CStrategy(void){delete m_signal;}
      void SetMode(int value){m_mode=value;}
      SIGNAL_DIRECTION GetSignal();
      SIGNAL_DIRECTION GetSignal(int mode);
};

SIGNAL_DIRECTION CStrategy :: GetSignal(){
   return GetSignal(m_mode);
}

SIGNAL_DIRECTION CStrategy :: GetSignal(int mode){
   switch(mode){
      case 1 :
         m_signal_cheikenashi.InitSignal();
         m_signal_machannel.InitSignal();
         if(m_signal_machannel.getMainValueSignal(1) == 1
            && m_signal_cheikenashi.getMainValueSignal(1) == 1) return DIRECTION_BUY;
         if(m_signal_machannel.getMainValueSignal(1) == -1
            && m_signal_cheikenashi.getMainValueSignal(1) == -1) return DIRECTION_SELL;
         break;
      case 2 :
         m_signal_cheikenashi.InitSignal();
         m_signal_machannel.InitSignal();
         m_signal_bbmacd.InitSignal();
         if(m_signal_machannel.getMainValueSignal(1) == 1
            && m_signal_cheikenashi.getMainValueSignal(1) == 1
            && m_signal_bbmacd.getMainValueSignal(1) == 1) return DIRECTION_BUY;
         if(m_signal_machannel.getMainValueSignal(1) == -1
            && m_signal_cheikenashi.getMainValueSignal(1) == -1
            && m_signal_bbmacd.getMainValueSignal(1) == -1) return DIRECTION_SELL;
         break;
      case 3 :
         m_signal_machannel.InitSignal();
         m_signal_bbmacd.InitSignal();
         if(m_signal_machannel.getMainValueSignal(1) == 1
            && m_signal_bbmacd.getCrossSignal(1) == 1){
            return DIRECTION_BUY;
         }
         if(m_signal_machannel.getMainValueSignal(1) == -1
            && m_signal_bbmacd.getCrossSignal(1) == -1){
            return DIRECTION_SELL;
         }
         break;
      case 4 :
         m_signal_machannel.InitSignal();
         m_signal_bbmacd.InitSignal();
         m_signal_cheikenashi.InitSignal();
         if(m_signal_machannel.getCrossSignal(1)==1
            && m_signal_bbmacd.getMainValueSignal(1)==1
            && m_signal_cheikenashi.getMainValueSignal(1)==1) return DIRECTION_BUY;
         if(m_signal_machannel.getCrossSignal(1)==-1
            && m_signal_bbmacd.getMainValueSignal(1)==-1
            && m_signal_cheikenashi.getMainValueSignal(1)==-1) return DIRECTION_SELL;
         break;
   }
   return DIRECTION_NONE;
}