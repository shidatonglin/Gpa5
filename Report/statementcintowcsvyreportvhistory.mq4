static int mPrev,totalPrev;
int m;

int init()
  {
   
   mPrev=Minute();
   totalPrev = 0;
   writeHistory();
   return(0);
  }
//+------------------------------------------------------------------+
int start()
  {
      //writeHistory();
  }
//+------------------------------------------------------------------+


void writeHistory(){
   int i,handle,hstTotal=HistoryTotal();
   m=Minute();
   if(hstTotal!=totalPrev)
      {
      mPrev=m;
      handle=FileOpen("OrdersReport.csv",FILE_WRITE|FILE_CSV,",");
      if(handle<0) return(0);
      FileWrite(handle,"#,Open Time,Type,Lots,Symbol,Price,Stop/Loss,Take Profit,Close Time,Close Price,"
         + "Profit,Comment,MagicNumber");
      for(i=0;i<hstTotal;i++)
         {
         if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==true)
            {
            FileWrite(handle,OrderTicket(),TimeToStr(OrderOpenTime(),TIME_DATE|TIME_MINUTES),OrderType()
               ,OrderLots(),OrderSymbol(),OrderOpenPrice(),OrderStopLoss(),OrderTakeProfit()
               ,TimeToStr(OrderCloseTime(),TIME_DATE|TIME_MINUTES),OrderClosePrice(),OrderProfit()
               ,OrderComment(),OrderMagicNumber());
            }
         }
      FileClose(handle);
      totalPrev = hstTotal;
      }
   return(0);
}