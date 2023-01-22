<%@ page contentType="text/html;charset=utf-8"%>
<%@ include file ="/ATWork/at_qdb/header.jsp" %>

<!-- http://192.168.231.30/ATWork/at_qdb/status.jsp?FORMID=0000000004&DOCID=JHOMS212210098721000&DEPTCD=1000001&EMPCD=191101&MISKEY=ALLSP20210000040&STATUS=CMPT&GWTYPE=0-06 -->
<!-- http://98.41.50.30/ATWork/at_qdb/status.jsp?FORMID=0000000004&DOCID=JHOMS212210098721000&DEPTCD=1000001&EMPCD=191101&MISKEY=ALLSP20210000040&STATUS=CMPT&GWTYPE=0-06 -->
<%
  String fvTmp    = "";
  String fvLogTmp = "";
  String fvErrMsg = "";

  /*  인자값 받기
  **/
  String fvMisKey    = HDUtils.getDefStr(request.getParameter("MISKEY"), "");
  String fvQdbFormID = HDUtils.getDefStr(request.getParameter("FORMID") , "");
  String fvEmpCode   = HDUtils.getDefStr(request.getParameter("EMPCD")  , "");
  String fvDeptCode  = HDUtils.getDefStr(request.getParameter("DEPTCD") , "");
  String fvApprID    = HDUtils.getDefStr(request.getParameter("DOCID")  , "");
  String fvGWSancST  = HDUtils.getDefStr(request.getParameter("GWTYPE") , ""); //전자결재 상태값
  String fvMisType   = HDUtils.getDefStr(request.getParameter("MISTYPE"), "");
  String fvQdbStatus = HDUtils.getDefStr(request.getParameter("STATUS") , ""); //ERP 상태값
  String fvDocNum    = HDUtils.getDefStr(request.getParameter("DOCNUM") , "");
  String fvFormNM    = "";
  /* */

  // 상태값 변경을 위한 MIS URI
  String fvURI    = "";
  String fvResult = "rslt=Y";

  /*  FIREWALL
  **/
  String fvIP = request.getServerName();

  String erpUrl =  AppFile.get("erp.url");
  String gwOutUrl = AppFile.get("gw.out.url");
  String eprOutUrl = AppFile.get("erp.out.url");
  String fvErpUrl = erpUrl;

  if(fvIP.equals(gwOutUrl)) fvErpUrl = eprOutUrl;
  /* */

  DBHandler fvDB_GW = new DBHandler();
  fvDB_GW.setDB("gw");

  getLogStart(fvMisKey);

  try
  {
    fvDocNum = "" + getDocregNO(fvDB_GW, fvApprID); //문서번호(한글)가 깨져서 나와 셀렉트해서 구해오도록 함.
    fvFormNM = getApprFormInfo(fvDB_GW, fvQdbFormID);

    if(!fvDocNum.equals(""))
    {
      fvLogTmp = fvApprID + "(" + fvDocNum + ")";
    }
    else
    {
      fvLogTmp = fvApprID;
    }

    getLogDefault(fvDB_GW, fvMisKey, fvQdbFormID, fvQdbStatus, fvEmpCode, fvDeptCode, fvLogTmp, fvGWSancST, fvMisType);


    if(fvMisKey.equals(""))
    {
      throw new Exception("연계시스템 PKEY가 없습니다.\r\n관리자에게 문의하시기 바랍니다.");
    }

	/*
    if(fvQdbFormID.equals("0000000002") ) //연동_휴가신청서
    {
      fvURI = "http://"+conf.szRMEIP + ":80/ATWork/at_qdb/t1.jsp";
    }
    else
    {
      throw new Exception("연계시스템 URL이 존재하지 않습니다.\r\n관리자에게 문의하시기 바랍니다.");
    }
	*/


	// ERP상태값 변경 페이지로 변경
	//fvURI = fvErpUrl + "/passBy/elecPay/receiveExtApproval.do" + "?misKey=" + fvMisKey + "&apprStatus=" + fvQdbStatus;
	fvURI = erpUrl + "/passBy/elecPay/receiveExtApproval.do";

    //QDB상태값 연동 Start
    ATWeb wWeb = new ATWeb();

    wWeb.setURL(fvURI);
    wWeb.setMethod("POST");

    wWeb.setWaitTime(10);  // 테스트 서버 환경이라 30초로 하지만 10초도 위험할수 있다. (Default : 10초)

    wWeb.addParam("misKey"       , fvMisKey);
    wWeb.addParam("apprStatus"   , fvQdbStatus);
    wWeb.submit();

    fvResult = ATComm.getReplace(wWeb.getContent(),"\r\n","");
    //QDB상태값 연동 End

    fvTmp = fvURI +
           "?misKey="       + fvMisKey    +
           "&apprStatus="   + fvQdbStatus;


    qdbstatus_logger.info("["+fvMisKey+"]MIS CALL URL    : "+ fvTmp);
    qdbstatus_logger.info("["+fvMisKey+"]MIS RESULT      : "+ fvResult);

    //if(!fvResult.equals("rslt=Y")) throw new Exception("연계시스템에 결재상태를 변경하는데 실패했습니다.\r\n관리자에게 문의하시기 바랍니다.\r\n[" + fvResult + "]");
    if(!fvResult.equals("SUCCESS")) throw new Exception("연계시스템에 결재상태를 변경하는데 실패했습니다.\r\n관리자에게 문의하시기 바랍니다.\r\n[" + fvResult + "]");

  }
  catch(Exception e)
  {
    System.out.println("[QDB STATUS ERROR] : " + e.getMessage());
    fvErrMsg = e.getMessage();
  }

  /*
   * 핸디 버그로 인하여 전결 서버처리전 실패시 문서가 생생되어
   * 임시로 DB에 인서트 된 데이터를 지운다.
   * */
  String wTargetStatus = "2-05|";

  if(!fvErrMsg.equals("") && wTargetStatus.indexOf(fvGWSancST) > -1)
  {
    try
    {
      // 트랜잭션 시작
      fvDB_GW.beginTrans();

      fvDB_GW.setPreparedQuery("DELETE FROM APPROVAL WHERE APPRID = ?");
      fvDB_GW.addPreparedValue(fvApprID);
      fvDB_GW.executePreparedQuery();

      fvDB_GW.setPreparedQuery("DELETE FROM FLDRMBR2 WHERE FLDRMBRID = ?");
      fvDB_GW.addPreparedValue(fvApprID);
      fvDB_GW.executePreparedQuery();

      // 트랜잭션 종료
      fvDB_GW.commit();

    }
    catch(Exception e)
    {
      // 트랜잭션 취소
      fvDB_GW.rollback();
      System.out.println("[QDB DELETE ERROR] : " + e.toString());
      e.printStackTrace();
    }
  }
  /* */

  /* QDB에 결과값 넣기
  * */
  try
  {
    // 오류여부
    String wRetCode = "";
    if(fvErrMsg.equals("")) wRetCode = "0";
    else                    wRetCode = "1";

    insertQDB (fvDB_GW, fvQdbFormID, fvDeptCode, fvEmpCode, fvErrMsg, wRetCode);

    //----------- QDBINFO UPDATE -----------
    if(fvErrMsg.equals(""))
    {
      //사용하지 않으므로 주석
      //getQDB_INFO_UPDATE(fvDB_GW, fvMisKey, fvQdbFormID, fvEmpCode, fvDeptCode, fvApprID, fvQdbStatus, "99", conf.szWEBSERVER_URL+"/ATWork/qdb/statusrev.jsp", "GW", fvMisType, "");
    }
    //----------- QDBINFO UPDATE -----------

  }
  catch(Exception e)
  {
    System.out.println("[QDB UPDATE ERROR] : " + e.toString());
    qdbstatus_logger.info("["+fvMisKey+"][QDB UPDATE ERROR]    : "+ e.toString());
    e.printStackTrace();
  }
  /* */

  getLogEnd(fvMisKey);


%>