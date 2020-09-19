#property copyright   "Sandro Boschetti - 05/08/2020"
#property description "Programa implementado em MQL5/Metatrader5"
#property description "Realiza backtests do método MMDI idealizado por mim"
#property link        "http://lattes.cnpq.br/9930983261299053"
#property version     "1.00"


//#property indicator_separate_window
#property indicator_chart_window

//--- input parameters
#property indicator_buffers 1
#property indicator_plots   1

//---- plot RSIBuffer
#property indicator_label1  "SrB-MMDI"
#property indicator_type1   DRAW_ARROW //DRAW_LINE
#property indicator_color1  Red //clrGreen//Red
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- input parameters
input int periodo = 1;                        //número de períodos
input double capitalInicial = 30000.00;       //Capital Inicial
input int lote = 100;                         //1 para WIN e 100 para ações
input bool reaplicar = false;                 //true: reaplicar o capital
input datetime t1 = D'2015.01.01 00:00:00';   //data inicial
input datetime t2 = D'2020.09.16 00:00:00';   //data final
//input datetime t2 = D'2020.08.09 00:00:01'; //data final

bool   comprado = false;
bool   jaCalculado = false;


//--- indicator buffers
double MyBuffer[];
//--- global variables
//bool tipoExpTeste = tipoExp;

int OnInit() {
   SetIndexBuffer(0,MyBuffer,INDICATOR_DATA);
   IndicatorSetString(INDICATOR_SHORTNAME,"SrB-MMDI("+string(periodo)+")");
   return(0);
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
                const int &spread[]) {
 
   int nOp = 0;
   double capital = capitalInicial;
   int nAcoes = 0;
   double precoDeCompra = 0;
   double lucroOp = 0;
   double lucroAcum = 0;
   double acumPositivo = 0;
   double acumNegativo = 0;
   int nAcertos = 0;
   int nErros = 0;
   double max = 0;
   
   // Para o cálculo do drawdown máximo
   double capMaxDD = capitalInicial;
   double capMinDD = capitalInicial;
   double rentDDMax = 0.00;
   double rentDDMaxAux = 0.00;
   
   // Essas duas variáveis não tem razão de ser neste método
   int nPregoes = 0;
   int nPregoesPos = 0;
   
   // Essas duas variáveis não tem razão de ser neste método
   datetime diaDaEntrada = time[0];
   double duracao = 0.0;
   
   // percentual dos trades que atingem a máxima. A outra parte sai pelo fechamento.
   double percRompMax = 0.5;
   
   double rentPorTradeAcum = 0.0;
   
      
   for(int i=periodo+1; i<rates_total;i++){
   
      if (time[i]>=t1 && time[i]<t2) {
      
         //Essa parte não tem sido usada neste método MMDI já que a posição é de um único dia
         nPregoes++;
         if(comprado){nPregoesPos++;}
      
         // Se posiciona na compra
         if(!comprado){
            //Parece fazer grande diferença se a comparação é com o igual ou não.
            //Embora a comparação com o igual é tem mais a ver com a lógica do método,
            //preferiu-se ser mais conservador sem o igual.
            //if( (open[i]>=low[i-1] && low[i]<=low[i-1]) || (open[i]<=low[i-1] && high[i]>=low[i-1]) ){
            if( (open[i]>low[i-1] && low[i]<low[i-1]) || (open[i]<low[i-1] && high[i]>low[i-1]) ){
               precoDeCompra = low[i-1];
               nAcoes = lote * floor(capital / (lote * precoDeCompra));
               comprado = true;
               nOp++;
               diaDaEntrada = time[i];
               MyBuffer[i] = precoDeCompra;
            } 
         }
         
         // Faz a venda
         if( comprado ){
         
         // A superação da máxima pode ter ocorrido antes da compra. Pode até mesmo ter ocorrido
         // uma segunda superação de máxima, mas não há como saber. Então, no caso de superação
         // da máxima, conservadoramente não atribui-se toda a saída na máxima.
            if (high[i]>=high[i-1]){
               //Não há como saber se o rompimento da máxima anterior ocorreu antes
               //da entrada ser acionada, portanto, faço uma ponderação.
               lucroOp = (high[i-1]*percRompMax + close[i]*(1.0 - percRompMax) - precoDeCompra) * nAcoes;
            }else{
               lucroOp = (close[i] - precoDeCompra) * nAcoes;
            }
            
            if(lucroOp>=0){
               nAcertos++;
               acumPositivo = acumPositivo + lucroOp;
               //rentPositiva = rentPositiva + lucroOp / (nAcoes*precoDeCompra);
            }else{
               nErros++;
               acumNegativo = acumNegativo + lucroOp;
               //rentNegativa = rentNegativa + lucroOp / (nAcoes*precoDeCompra);
            }
            
            lucroAcum = lucroAcum + lucroOp;
            
            if(reaplicar == true){capital = capital + lucroOp;}
            
            rentPorTradeAcum = rentPorTradeAcum + (lucroOp / (nAcoes * precoDeCompra));

            // ************************************************
            // Início: Cálculo do Drawdown máximo
            if ((lucroAcum+capitalInicial) > capMaxDD) {
               capMaxDD = lucroAcum + capitalInicial;
               capMinDD = capMaxDD;
            } else {
               if ((lucroAcum+capitalInicial) < capMinDD){
                  capMinDD = lucroAcum + capitalInicial;
                  rentDDMaxAux = (capMaxDD - capMinDD) / capMaxDD;
                  if (rentDDMaxAux > rentDDMax) {
                     rentDDMax = rentDDMaxAux;
                  }
               }
            }
            // Fim: Cálculo do Drawdown máximo
            // ************************************************
            
            nAcoes = 0;
            precoDeCompra = 0;
            comprado = false;
         } // fim do "if" da venda.
   } // fim do "if" do intervalo de tempo 
   } // fim do "for"
   
   
   double  dias = (t2-t1)/(60*60*24);
   double  anos = dias / 365.25;
   double meses = anos * 12;
   double rentTotal = 100.0*((lucroAcum+capitalInicial)/capitalInicial - 1);
   double rentMes = 100.0*(pow((1+rentTotal/100.0), 1/meses) - 1);

   string nome = Symbol();

   if(!jaCalculado){
      printf("Ativo: %s, Programa: SrB_MMDI", nome);
      printf("Período de Teste: %s a %s", TimeToString(t1), TimeToString(t2));
      if(reaplicar){printf("Reinvestimento dos Lucros: SIM");}else{printf("Reinvestimento dos Lucros: NÃO");}
      printf("#Op: %d, #Pregões: %d, Capital Inicial: %.2f", nOp, nPregoes, capitalInicial);
      printf("Somatório dos Valores Positivos: %.2f e Negativos: %.2f e Diferença: %.2f", acumPositivo, acumNegativo, acumPositivo+acumNegativo);      
      printf("Lucro: %.2f, Capital Final: %.2f",  floor(lucroAcum), floor(capital));
      printf("#Acertos: %d (%.2f%%), #Erros: %d (%.2f%%)", nAcertos, 100.0*nAcertos/nOp,  nErros, 100.0*nErros/nOp);
      printf("Pay-off: %.2f e G/R: %.2f", - (acumPositivo/nAcertos) / (acumNegativo/nErros), -acumPositivo/acumNegativo);
      //printf("#PregoesPosicionado: %d, #PregoesPosicionado/Op: %.2f", nPregoesPos, 1.0*nPregoesPos/nOp);
      printf("Rentabilidade Mensal: %.2f%% (juros compostos) ou %.2f%% (juros simples)", rentMes, rentTotal/meses);
      //printf("Fração de pregões posicionado: %.2f%%", 100.0*nPregoesPos/nPregoes);
      if(reaplicar){
         printf("#Meses: %.0f, #Op/mes: %.2f, Rentabilidade/Op: %.2f%%", meses, nOp/meses, rentMes/(nOp/meses));
      }else{
         printf("#Meses: %.0f, #Op/mes: %.2f, Rentabilidade/Op: %.2f%%", meses, nOp/meses, rentTotal/nOp);
      }
      printf("Drawdown Máximo: %.2f%%", 100.0 * rentDDMax);
      printf("Rentabilidade média por Trade: %.4f%%: ", 100 * rentPorTradeAcum / nOp);
      printf("Ganho Percentual Médio: %.2f%%", 100*(acumPositivo/capital)/nAcertos);
      printf("Perda Percentual Média: %.2f%%", 100*(acumNegativo/capital)/nErros);      
      printf("");
   }
   jaCalculado = true;

   return(rates_total);
}

