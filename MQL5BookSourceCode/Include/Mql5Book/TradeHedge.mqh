//+------------------------------------------------------------------+
//|                                                   TradeHedge.mqh |
//|                                                     Andrew Young |
//|                                 http://www.expertadvisorbook.com |
//+------------------------------------------------------------------+

#property copyright "Andrew Young"
#property link      "http://www.expertadvisorbook.com"

/*
 Creative Commons Attribution-NonCommercial 3.0 Unported
 http://creativecommons.org/licenses/by-nc/3.0/

 You may use this file in your own personal projects. You may 
 modify it if necessary. You may even share it, provided the 
 copyright above is present. No commercial use is permitted. 
*/


#define MAX_RETRIES 5		// Max retries on error
#define RETRY_DELAY 3000	// Retry delay in ms

#include <errordescription.mqh>
#include <Mql5Book\Trade.mqh>


//+----------------------------------------------------------------------+
//| CTradeHedge Class - Open, Close and Modify Orders for Hedging Accounts                                                           |
//+----------------------------------------------------------------------+

class CTradeHedge : public CTrade
{
	protected:	
		ulong OpenHedgePosition(string pSymbol, ENUM_ORDER_TYPE pType, double pVolume, double pStop = 0, double pProfit = 0, string pComment = NULL);
		
	public:	
		ulong BuyHedge(string pSymbol, double pVolume, double pStop = 0, double pProfit = 0, string pComment = NULL);
		ulong SellHedge(string pSymbol, double pVolume, double pStop = 0, double pProfit = 0, string pComment = NULL);
		
		bool ModifyHedge(ulong pTicket, double pStop, double pProfit = 0);
		bool CloseHedge(ulong pTicket, double pVolume = 0, string pComment = NULL);
		bool CloseByHedge(ulong pTicket, ulong pOppositeTicket, double pVolume = 0, string pComment = NULL);
};


// Open position
ulong CTradeHedge::OpenHedgePosition(string pSymbol, ENUM_ORDER_TYPE pType, double pVolume, double pStop = 0, double pProfit = 0, string pComment = NULL)
{
	request.action = TRADE_ACTION_DEAL;
	request.symbol = pSymbol;
	request.type = pType;
	request.sl = pStop;
	request.tp = pProfit;
	request.comment = pComment;
	request.volume = pVolume;
	request.position = 0;   // Reset ticket number
	
	// Order loop
	int retryCount = 0;
	int checkCode = 0;
	
	do 
	{
		if(pType == ORDER_TYPE_BUY) request.price = SymbolInfoDouble(pSymbol,SYMBOL_ASK);
		else if(pType == ORDER_TYPE_SELL) request.price = SymbolInfoDouble(pSymbol,SYMBOL_BID);
				
		OrderSend(request,result);
		
		checkCode = CheckReturnCode(result.retcode);
		
		if(checkCode == CHECK_RETCODE_OK) break;
		else if(checkCode == CHECK_RETCODE_ERROR)
		{
			string errDesc = TradeServerReturnCodeDescription(result.retcode);
			Alert("Open market order: Error ",result.retcode," - ",errDesc);
			break;
		}
		else
		{
			Print("Server error detected, retrying...");
			Sleep(RETRY_DELAY);
			retryCount++;
		}
	}
	while(retryCount < MAX_RETRIES);
	
	if(retryCount >= MAX_RETRIES)
	{
		string errDesc = TradeServerReturnCodeDescription(result.retcode);
		Alert("Max retries exceeded: Error ",result.retcode," - ",errDesc);
	}
	
	string orderType = CheckOrderType(pType);
	
	string errDesc = TradeServerReturnCodeDescription(result.retcode);
	Print("Open ",orderType," order #",result.deal,": ",result.retcode," - ",errDesc,", Volume: ",result.volume,", Price: ",result.price,", Bid: ",result.bid,", Ask: ",result.ask);
	
	if(checkCode == CHECK_RETCODE_OK) 
	{
		Comment(orderType," position opened at ",result.price," on ",pSymbol);
		return(result.deal);
	}
	else return(0);
}

// Modify position
bool CTradeHedge::ModifyHedge(ulong pTicket, double pStop, double pProfit=0.000000)
{
	request.action = TRADE_ACTION_SLTP;
	request.sl = pStop;
	request.tp = pProfit;
	request.position = pTicket;
	
	// Order loop
	int retryCount = 0;
	int checkCode = 0;
	
	do 
	{
		OrderSend(request,result);
		
		checkCode = CheckReturnCode(result.retcode);
		
		if(checkCode == CHECK_RETCODE_OK) break;
		else if(checkCode == CHECK_RETCODE_ERROR)
		{
			string errDesc = TradeServerReturnCodeDescription(result.retcode);
			Alert("Modify position: Error ",result.retcode," - ",errDesc);
			break;
		}
		else
		{
			Print("Server error detected, retrying...");
			Sleep(RETRY_DELAY);
			retryCount++;
		}
	}
	while(retryCount < MAX_RETRIES);
	
	if(retryCount >= MAX_RETRIES)
	{
		string errDesc = TradeServerReturnCodeDescription(result.retcode);
		Alert("Max retries exceeded: Error ",result.retcode," - ",errDesc);
		return(false);
	}

	string errDesc = TradeServerReturnCodeDescription(result.retcode);
	PositionSelectByTicket(pTicket);
	string symbol = PositionGetString(POSITION_SYMBOL);
	Print("Modify position #",pTicket,": ",result.retcode," - ",errDesc,", SL: ",request.sl,", TP: ",request.tp,", Bid: ",SymbolInfoDouble(symbol,SYMBOL_BID),", Ask: ",SymbolInfoDouble(symbol,SYMBOL_ASK),", Stop Level: ",SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL));
	
	if(checkCode == CHECK_RETCODE_OK) 
	{
		Comment("Position #",pTicket," modified on ",symbol,", SL: ",request.sl,", TP: ",request.tp);
		return(true);
	}
	else return(false);
}


// Close position
bool CTradeHedge::CloseHedge(ulong pTicket, double pVolume=0.000000, string pComment=NULL)
{
	request.action = TRADE_ACTION_DEAL;
	request.position = pTicket;
			
	double closeLots = 0;
	long openType = WRONG_VALUE;
	string symbol;
	
	if(PositionSelectByTicket(pTicket) == true)
	{
		closeLots = PositionGetDouble(POSITION_VOLUME);
		openType = PositionGetInteger(POSITION_TYPE);
		symbol = PositionGetString(POSITION_SYMBOL);
		request.sl = 0;   // Reset SL and TP when closing a position
		request.tp = 0; 
	}
	else return(false);
	
	if(pVolume > closeLots || pVolume <= 0) request.volume = closeLots; 
	else request.volume = pVolume;
	
	// Order loop
	int retryCount = 0;
	int checkCode = 0;
	
	do 
	{
		if(openType == POSITION_TYPE_BUY)
		{
			request.type = ORDER_TYPE_SELL;
			request.price = SymbolInfoDouble(symbol,SYMBOL_BID);
		}
		else if(openType == POSITION_TYPE_SELL)
		{
			request.type = ORDER_TYPE_BUY;
			request.price = SymbolInfoDouble(symbol,SYMBOL_ASK);
		}

		OrderSend(request,result);
		
		checkCode = CheckReturnCode(result.retcode);
		
		if(checkCode == CHECK_RETCODE_OK) break;
		else if(checkCode == CHECK_RETCODE_ERROR)
		{
			string errDesc = TradeServerReturnCodeDescription(result.retcode);
			Alert("Close position: Error ",result.retcode," - ",errDesc);
			break;
		}
		else
		{
			Print("Server error detected, retrying...");
			Sleep(RETRY_DELAY);
			retryCount++;
		}
	}
	while(retryCount < MAX_RETRIES);
	
	if(retryCount >= MAX_RETRIES)
	{
		string errDesc = TradeServerReturnCodeDescription(result.retcode);
		Alert("Max retries exceeded: Error ",result.retcode," - ",errDesc);
	}
	
	string posType;
	if(openType == POSITION_TYPE_BUY) posType = "Buy";
	else if(openType == POSITION_TYPE_SELL) posType = "Sell";
	
	string errDesc = TradeServerReturnCodeDescription(result.retcode);
	Print("Close ",posType," position #",result.deal,": ",result.retcode," - ",errDesc,", Volume: ",result.volume,", Price: ",result.price,", Bid: ",result.bid,", Ask: ",result.ask);
	
	if(checkCode == CHECK_RETCODE_OK) 
	{
		Comment(posType," position closed on ",symbol," at ",result.price);
		return(true);
	}
	else return(false);
}


// Close position by an opposite position
bool CTradeHedge::CloseByHedge(ulong pTicket, ulong pOppositeTicket, double pVolume=0.000000, string pComment=NULL)
{
	request.action = TRADE_ACTION_DEAL;
	request.position = pTicket;
	request.position_by = pOppositeTicket;
			
	double closeLots = 0;
	long openType = WRONG_VALUE;
	string symbol;
	
	if(PositionSelectByTicket(pTicket) == true)
	{
		closeLots = PositionGetDouble(POSITION_VOLUME);
		openType = PositionGetInteger(POSITION_TYPE);
		symbol = PositionGetString(POSITION_SYMBOL);
		request.sl = 0;   // Reset SL and TP when closing a position
		request.tp = 0; 
	}
	else return(false);
	
	if(pVolume > closeLots || pVolume <= 0) request.volume = closeLots; 
	else request.volume = pVolume;
	
	// Order loop
	int retryCount = 0;
	int checkCode = 0;
	
	do 
	{
		if(openType == POSITION_TYPE_BUY)
		{
			request.type = ORDER_TYPE_SELL;
			request.price = SymbolInfoDouble(symbol,SYMBOL_BID);
		}
		else if(openType == POSITION_TYPE_SELL)
		{
			request.type = ORDER_TYPE_BUY;
			request.price = SymbolInfoDouble(symbol,SYMBOL_ASK);
		}

		OrderSend(request,result);
		
		checkCode = CheckReturnCode(result.retcode);
		
		if(checkCode == CHECK_RETCODE_OK) break;
		else if(checkCode == CHECK_RETCODE_ERROR)
		{
			string errDesc = TradeServerReturnCodeDescription(result.retcode);
			Alert("Close position: Error ",result.retcode," - ",errDesc);
			break;
		}
		else
		{
			Print("Server error detected, retrying...");
			Sleep(RETRY_DELAY);
			retryCount++;
		}
	}
	while(retryCount < MAX_RETRIES);
	
	if(retryCount >= MAX_RETRIES)
	{
		string errDesc = TradeServerReturnCodeDescription(result.retcode);
		Alert("Max retries exceeded: Error ",result.retcode," - ",errDesc);
	}
	
	string posType;
	if(openType == POSITION_TYPE_BUY) posType = "Buy";
	else if(openType == POSITION_TYPE_SELL) posType = "Sell";
	
	string errDesc = TradeServerReturnCodeDescription(result.retcode);
	Print("Close ",posType," position #",result.deal,": ",result.retcode," - ",errDesc,", Volume: ",result.volume,", Price: ",result.price,", Bid: ",result.bid,", Ask: ",result.ask);
	
	if(checkCode == CHECK_RETCODE_OK) 
	{
		Comment(posType," position closed on ",symbol," at ",result.price);
		return(true);
	}
	else return(false);
}


// Trade opening shortcuts
ulong CTradeHedge::BuyHedge(string pSymbol,double pVolume,double pStop=0.000000,double pProfit=0.000000,string pComment=NULL)
{
	ulong ticket = OpenHedgePosition(pSymbol,ORDER_TYPE_BUY,pVolume,pStop,pProfit,pComment);
	return(ticket);
}

ulong CTradeHedge::SellHedge(string pSymbol,double pVolume,double pStop=0.000000,double pProfit=0.000000,string pComment=NULL)
{
	ulong ticket = OpenHedgePosition(pSymbol,ORDER_TYPE_SELL,pVolume,pStop,pProfit,pComment);
	return(ticket);
}


//+------------------------------------------------------------------+
//| Position Information                                             |
//+------------------------------------------------------------------+


string PositionComment(ulong pTicket = 0)
{
	bool select = false;
   if(pTicket > 0) select = PositionSelectByTicket(pTicket);
	
	if(select == true) return(PositionGetString(POSITION_COMMENT));
	else return(NULL);
}


long PositionType(ulong pTicket = 0)
{
   bool select = false;
   if(pTicket > 0) select = PositionSelectByTicket(pTicket);
	
	if(select == true) return(PositionGetInteger(POSITION_TYPE));
	else return(WRONG_VALUE);
}


long PositionIdentifier(ulong pTicket = 0)
{
   bool select = false;
   if(pTicket > 0) select = PositionSelectByTicket(pTicket);
	
	if(select == true) return(PositionGetInteger(POSITION_IDENTIFIER));
	else return(WRONG_VALUE);
}


double PositionOpenPrice(ulong pTicket = 0)
{
   bool select = false;
   if(pTicket > 0) select = PositionSelectByTicket(pTicket);
	
	if(select == true) return(PositionGetDouble(POSITION_PRICE_OPEN));
	else return(WRONG_VALUE);
}


long PositionOpenTime(ulong pTicket = 0)
{
   bool select = false;
   if(pTicket > 0) select = PositionSelectByTicket(pTicket);
	
	if(select == true) return(PositionGetInteger(POSITION_TIME));
	else return(WRONG_VALUE);
}


double PositionVolume(ulong pTicket = 0)
{
   bool select = false;
   if(pTicket > 0) select = PositionSelectByTicket(pTicket);
	
	if(select == true) return(PositionGetDouble(POSITION_VOLUME));
	else return(WRONG_VALUE);
}


double PositionStopLoss(ulong pTicket = 0)
{
   bool select = false;
   if(pTicket > 0) select = PositionSelectByTicket(pTicket);
	
	if(select == true) return(PositionGetDouble(POSITION_SL));
	else return(WRONG_VALUE);
}


double PositionTakeProfit(ulong pTicket = 0)
{
   bool select = false;
   if(pTicket > 0) select = PositionSelectByTicket(pTicket);
	
	if(select == true) return(PositionGetDouble(POSITION_TP));
	else return(WRONG_VALUE);
}


double PositionProfit(ulong pTicket = 0)
{
	bool select = false;
   if(pTicket > 0) select = PositionSelectByTicket(pTicket);
	
	if(select == true) return(PositionGetDouble(POSITION_PROFIT));
	else return(WRONG_VALUE);
}

string PositionMagicNumber(ulong pTicket = 0)
{
   bool select = false;
   if(pTicket > 0) select = PositionSelectByTicket(pTicket);
	
	if(select == true) return(PositionGetString(POSITION_MAGIC));
	else return(NULL);
}