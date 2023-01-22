<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%response.setDateHeader("Expires", -999999999);%>

<%@ include file ="header.jsp" %>

<!-- http://192.168.231.30/ATWork/at_gian/gian.jsp?PKEY=ALLSP20210000040&EMPCODE=191101&F=0000000004 -->
<!-- http://98.41.50.30/ATWork/at_gian/gian.jsp?PKEY=ALLSP20210000040&EMPCODE=191101&F=0000000004 -->
<%
  /* 인자값 받기
  * */
  String fvPKEY       = ATComm.getRequest(request, "PKEY"       , "");     // 연동시스템 PKEY
  String fvEmpCode    = ATComm.getRequest(request, "EMPCODE"    , "");     // 사번"1993016"
  String fvENKey      = ATComm.getRequest(request, "ENCRYPTKEY" , "");     // AES 암호화Key
  String fvFORMID     = ATComm.getRequest(request, "F"          , "");     // 서식 HAI_FORM의 FORM_ID
  String fvMETHOD     = ATComm.getRequest(request, "M"          , "GIAN"); // 첨부연동 여부 attach
  String fvATC        = ATComm.getRequest(request, "ATC"        , "0");    // 첨부연동 갯수
  String fvUNDOCID    = ATComm.getRequest(request, "UNDOCID"    , "");     // 압축해제할 GW문서ID
  String fvUNMODE     = ATComm.getRequest(request, "UNMODE"     , "all");  // 압축해제할 GW문서ID MODE : all(모두), body(본문만), attach(첨부만)
  String fvMet        = ATComm.getRequest(request, "MET"        , "N");    // Method에서 POST방식에 따라 문서 VIEW(Y: POST, N : 체크않함.)
  String fvRef        = ATComm.getRequest(request, "REF"        , "N");    // 이전페이지 정보확인하여 허가된 IP가 아니면 호출 불가

  fvMETHOD = fvMETHOD.toUpperCase();

  String fvDeEmpCode             = "";
  String fvErr                   = "";
  String fvExcErr                = "";
  String fvUserID                = "";
  String fvDeptCD                = "";
  String fvK                     = "";

  //사용자 IP 가져오기
  Enumeration fvHeader           = request.getHeaderNames();
  String fvClientIP              = request.getRemoteAddr();
  String fvServerIP              = conf.szWEBSERVER_URL;
  //String fvServerIP              = "http://" + request.getServerName();

  //String fvHost                  = conf.szGPIP + ":" + ((int)(Math.random() * 7)+9030);//9030 ~ 9040 사용시 ex> 9030~9036 사용시 : (int)(Math.random() * 7)+9030 conf.nGPPort;
  String fvHost                  = request.getServerName() + ":" + ((int)(Math.random() * 7)+9030);//9030 ~ 9040 사용시 ex> 9030~9036 사용시 : (int)(Math.random() * 7)+9030 conf.nGPPort;

  String fvReqPage               = ATComm.getRequest(request, "referer","");;
  String fvPostMethod            = request.getMethod();

  String fvQdbFormID             = "";
  String fvApprFormID            = "";
  String fvApprFormName          = "";
  String fvWordType              = "";

  String fvAttachINI             = "";
  String fvClientURL             = "";

  // 에러메세지 *^^* <-- 이 문자를 스크립트에서 엔터값으로 치환
  String fsError_Msg00 = "[결재연동 페이지]*^^*정상적인 접근이 아닙니다.";
  String fsError_Msg01 = "[결재연동 페이지]*^^*그룹웨어에서 사용자 정보를 확인할 수 없어 기안기를 호출하지 못했습니다.*^^**^^*관리자에게 문의하시기 바랍니다.";
  String fsError_Msg02 = "[결재연동 페이지]*^^*그룹웨어에서 연동하고자하는 결재서식을 찾지 못하였습니다.*^^**^^*관리자에게 문의하시기 바랍니다.";
  String fsError_Msg03 = "[결재연동 페이지]*^^*결재연동 페이지 호출중 오류가 발생하였습니다.*^^**^^*관리자에게 문의하시기 바랍니다.*^^**^^*ErorMsg : #EXCERR#";
  String fsError_Msg04 = "[결재연동 페이지]*^^*그룹웨어에서 겸직자 정보를 확인할 수 없어 기안하지 못하였습니다.*^^**^^*관리자에게 문의하시기 바랍니다.";

  DBHandler fvDB_GW = new DBHandler();
  fvDB_GW.setDB("gw");

  // 현재일 셋팅
  ATDate fvNow = new ATDate();

  System.out.println("fvHost : " + fvHost);

  /* 전자결재 로그인하기
  * */
  try
  {
    qdbgian_logger.info("============== 결재연동 기안기호출 START["+fvPKEY+"] =================");
    qdbgian_logger.info("["+fvPKEY+"]결재연동 : "+ fvNow.getDate());

	System.out.println("============== 결재연동 기안기호출 START["+fvPKEY+"] =================");
	System.out.println("["+fvPKEY+"]결재연동 : "+ fvNow.getDate());

    if(fvMet.equals("Y"))
    {
      if(!fvPostMethod.equalsIgnoreCase("POST") ) //POST방식이 아니면 페이지에 접근할 수 없도록
      {
        fvErr = fsError_Msg00;
        throw new Exception(fvErr);
      }
    }

    if(fvRef.equals("Y")) //허가된 도메인 여부 확인
    {
      boolean IS_PERMIT = false;
      for(int i=0; i < gvPermitDomain.length; i++)
      {
        if(fvReqPage.indexOf(gvPermitDomain[i]) > -1)
        {
          IS_PERMIT = true;
          break;
        }
      }
      if(!IS_PERMIT)
      {
        fvErr = fsError_Msg00;
        throw new Exception(fvErr);
      }
    }

	// 2021-08-09 aintop leedh AES 주석
	/*
    if(!fvENKey.equals(""))
    {
      fvDeEmpCode = getDecryptAES(fvEmpCode, fvENKey);
      if(fvDeEmpCode.equals("")){throw new Exception("전달된 사원번호가 잘못 되었습니다.");}
    }
    else
    {
      fvDeEmpCode = fvEmpCode;
    }
	*/

	fvDeEmpCode = fvEmpCode;
    qdbgian_logger.info("["+fvPKEY+"]사원번호 : "+ fvDeEmpCode);
    System.out.println("["+fvPKEY+"]사원번호 : "+ fvDeEmpCode);

    //사용자에 그룹웨어 KEY생성
    fvK  = getKeyAdd(fvDB_GW, fvDeEmpCode, fvClientIP, fvServerIP);
	System.out.println("fvK : " + fvK);
	System.out.println("fvK : " + fvK);
	System.out.println("fvK : " + fvK);
    if(fvK.equals("NOTKEY"))
    {
      fvErr = fsError_Msg01;
      throw new Exception(fvErr);
    }
    qdbgian_logger.info("["+fvPKEY+"]K값 : "+ fvK);
    System.out.println("["+fvPKEY+"]K값 : "+ fvK);

    //사용자에 DEPTCD
    fvDeptCD  = getDeptCD(fvDB_GW, fvDeEmpCode);
    if(fvDeptCD.equals("NOTDEPTCD"))
    {
      fvErr = fsError_Msg01;
      throw new Exception(fvErr);
    }
    qdbgian_logger.info("["+fvPKEY+"]부서코드 : "+ fvDeptCD);
    System.out.println("["+fvPKEY+"]부서코드 : "+ fvDeptCD);

    //사용자에 USERID
    fvUserID  = getUserID(fvDB_GW, fvDeEmpCode);
    if(fvUserID.equals("NOTUSERID"))
    {
      fvErr = fsError_Msg01;
      throw new Exception(fvErr);
    }
    qdbgian_logger.info("["+fvPKEY+"]사용자ID : "+ fvUserID);
    System.out.println("["+fvPKEY+"]사용자ID : "+ fvUserID);

    // 폼정보 구하기
    Hashtable wApprForm = null;
    fvQdbFormID     = getFormID(fvFORMID);
    wApprForm       = getApprFormInfo(fvDB_GW, fvQdbFormID);
    fvApprFormID    =  HDUtils.getDefStr((String)wApprForm.get("FORMID"),"");
    fvApprFormName  =  HDUtils.getDefStr((String)wApprForm.get("FORMNAME"),"");
    fvWordType      =  HDUtils.getDefStr((String)wApprForm.get("WORDTYPE"),"");
    wApprForm.clear();
    qdbgian_logger.info("["+fvPKEY+"]서식ID   : "+ fvApprFormID);
    System.out.println("["+fvPKEY+"]서식ID   : "+ fvApprFormID);
    qdbgian_logger.info("["+fvPKEY+"]서식명   : "+ fvApprFormName);
    System.out.println("["+fvPKEY+"]서식명   : "+ fvApprFormName);

    if(fvApprFormID.equals("NOT") )
    {
      fvErr = fsError_Msg02;
    }

    //이전에 연동했던 파일 삭제 및 폴더 만들기
    checkSaveDir(fvUnzipBasicPath + fvDeEmpCode);

    /* MIS첨부 갯수 확인
    * */
    if(fvMETHOD.equals("ATTACH") && !fvATC.equals("0"))
    {
      //** 첨부파일 저장 경로 **/
      String wUnzipPath      = "";          // 압축해제 경로

      // 결재본문/첨부 압축해제 디렉토리 생성 체크
      wUnzipPath = fvUnzipBasicPath + fvDeEmpCode;
      checkSaveDir(wUnzipPath);
      qdbgian_logger.info("["+fvPKEY+"]첨부갯수 : "+ fvATC);
      System.out.println("["+fvPKEY+"]첨부갯수 : "+ fvATC);

      String wErr = getMisAttCheck(fvDB_GW, fvPKEY,  "MIS",  fvATC);
      if(wErr.equals("ERROR"))
      {
        fvErr = "결재연동 페이지 호출중 MIS 첨부갯수가 일치하지 않습니다.";
        throw new Exception(fvErr);
      }
    }

    /* 완료문서 첨부연동 추가
    * */
    if(fvErr.equals("") && !fvUNDOCID.equals("") && !fvUNDOCID.equals("|"))
    {
      fvMETHOD = "ATTACH";
      qdbgian_logger.info("["+fvPKEY+"]완료문서ID   : "+ fvUNDOCID);
      System.out.println("["+fvPKEY+"]완료문서ID   : "+ fvUNDOCID);

      //** 첨부파일 저장 경로 **/
      String wUnzipPath       = "";          // 압축해제 경로
      String wReturn          = "";          // 압축해제 성고여부

      //** 압축해제 대상 문서 **/
      int fnDocCount       = 0;              // 압축해제 대상 문서 카운트
      String [] fvDocList  = null;           // 압축해제 대상 문서ID

      //** 결재본문/첨부 압축해제 처리 **/
      try
      {
        // 기존연동 실패시 가비지 데이터 삭제
        initUnzipDoc(fvDB_GW, fvPKEY);

        if(fvUNDOCID.indexOf("|") > -1)
        {
          if(fvUNDOCID.substring(fvUNDOCID.length() -1).equals("|")) fvUNDOCID = fvUNDOCID.substring(0, fvUNDOCID.length() -1);
        }

        fvDocList = ATComm.split(fvUNDOCID, "|");

        fnDocCount = fvDocList.length;

        // 결재본문/첨부 압축해제 디렉토리 생성 체크
        wUnzipPath =fvUnzipBasicPath + fvDeEmpCode;
        checkSaveDir(wUnzipPath);

        for(int n=0; n<fnDocCount; n++)
        {
          // 결재본문/첨부 압축해제 처리
          wReturn = getUnzipDoc(fvDB_GW, fvDeEmpCode, fvDocList[n], wUnzipPath, fvUNMODE, fvPKEY);

          if(!wReturn.equals("SUCCESS"))
          {
            fvErr = "결재연동 페이지 호출중 첨부연동에서 오류가 발생하였습니다.";
          }
        }

      }
      catch (Exception e)
      {
        fvErr = "결재연동 페이지 호출중 오류가 발생하였습니다.*^^*"+wReturn;
        e.printStackTrace();
        System.out.println("doc unzip error : " + e.toString());
      }
    }

    if(fvErr.equals(""))
    {
      //attach.ini 만들기
      if(fvErr.equals("") && fvMETHOD.equals("ATTACH") )
      {
        fvAttachINI = getAttachINI(fvDB_GW, fvDeEmpCode, fvK, fvPKEY, fvWordType);

        if(fvAttachINI.equals("ERROR"))
        {
          fvErr = "결재연동 페이지 호출중 첨부연동에서 오류가 발생하였습니다.";
          throw new Exception(fvErr);
        }
      }

      //기안기 호출 URL 구하기
      if(fvWordType.equals("3")) //HWP
      {
        fvClientURL = getClientURL(fvApprFormID, fvUserID, fvHost, fvK, fvAttachINI, fvPKEY);
      }
      else if(fvWordType.equals("7")) //HTMl
      {
        fvClientURL = "/bms/com/hs/gwweb/appr/retrieveDoccrdWritng.act";
      }
      else
      {
        fvErr = "연동 호출 URL이 정의되어 있지 않습니다.";
        throw new Exception(fvErr);
      }
    }
    qdbgian_logger.info("["+fvPKEY+"]첨부연동 : "+ fvMETHOD);
    System.out.println("["+fvPKEY+"]첨부연동 : "+ fvMETHOD);
    qdbgian_logger.info("["+fvPKEY+"]기안기호출: "+ fvClientURL);
    System.out.println("["+fvPKEY+"]기안기호출: "+ fvClientURL);

    //----------- QDBINFO 초기값 입력 -----------
    if(!fvPKEY.equals(""))
    {
      //사용하지 않으므로 주석
      //getQDB_INFO_INSERT(fvDB_GW, fvPKEY, fvQdbFormID, fvDeEmpCode, fvDeptCD, "", "00", "10", conf.szWEBSERVER_URL+"/ATWork/at_qdb/statusrev.jsp", "GW");
    }
    //----------- QDBINFO 초기값 입력 -----------
  }
  catch(Exception e)
  {
    if(fvErr.equals(""))
    {
      fvErr = fsError_Msg03;
      //fvExcErr = ExceptionUtils.getRootCauseMessage(e);
      //fvErr = ATComm.getReplace(fvErr, "#EXCERR#", fvExcErr.substring(0,fvExcErr.length()));
    }
  }

  qdbgian_logger.info("["+fvPKEY+"]ERR MSG  : "+ ATComm.getReplace(fvErr,"*^^*"," "));
  qdbgian_logger.info("============== 결재연동 기안기호출 END ["+fvPKEY+"] =================");
  qdbgian_logger.info("");
  System.out.println("["+fvPKEY+"]ERR MSG  : "+ ATComm.getReplace(fvErr,"*^^*"," "));
  System.out.println("============== 결재연동 기안기호출 END ["+fvPKEY+"] =================");
  System.out.println("");

%>
<!DOCTYPE HTML>
<HTML>
<HEAD><TITLE>결재연동</TITLE>
<META http-equiv="Content-Type" content="text/html; charset=utf-8">

<script type="text/javascript" src="/js/lib/jQuery/jquery-1.8.3.js"></script>
<script language="javascript" type="text/javascript" src="/bms/js/com/hs/gwweb/appr/commutil.js"></script>
<Script Language="JavaScript">

  var wErr = '<%=fvErr%>';
  wErr = wErr.split('*^^*').join('\n');  //replaceAll이 안먹어서 대체 ㅡㅡ;;

  var objRun;
  var fvQdbWordType = "<%=fvWordType%>";

  $(document).ready(function(){
    fsOnLoad('<%=fvK%>');
  });

  function closeWindow()
  {
    clearInterval(objRun);
    //window.close();
    try{
        window.open('', '_self').close();
      }catch(e){}

    try{
        window.open('about:blank','_self').close();
      }catch(e){}

      try{
        window.close();
      }catch(e){}

      try{
        window.opener = 'self';
        window.open('','_parent','');
        window.close();
      }catch(e){}

      try{
        top.window.opener = top;
        top.window.open('','_parent','');
        top.window.close();
      }catch(e){}
  }

  function fsOnLoad(K)
  {
    if(wErr)
    {
      try
      {
        alert(wErr);
      }
      catch (e)
      {
        alert("결재연동 페이지 호출중 오류가 발생하였습니다. 관리자에게 문의하시기 바랍니다.\r\n\r\nErrorMsg : <%=fvExcErr%>");
      }

      try{
        window.close();
      }catch(e){}

      try{
        top.window.opener = top;
        top.window.open('','_parent','');
        top.window.close();
      }catch(e){}

      try{
        window.opener = 'self';
        window.open('','_parent','');
        window.close();
      }catch(e){}

      try{
        window.open('', '_self').close();
      }catch(e){}

    }
    else
    {
      var dataValue = {"K":K};
      var url = "/bms/login.cmmn";
      jQuery.ajax({
        type:"post",
        cache:false,
        async:false,
        url:url,
        data:dataValue,
        success: function(data, status){
          isWorking = false
          fsCallGian();
        }
      });
    }

  }

  function fsCallGian()
  {
    if(fvQdbWordType == '3')
    {
      document.location.href="<%=fvClientURL%>";
      objRun = setInterval("closeWindow()", 1000);
    }
    else if(fvQdbWordType == '7')
    {
      $('#K').val('<%=fvK%>');
      $('#USERID').val('<%=fvUserID%>');
      $('#FORMID').val('<%=fvApprFormID%>');
      $('#WORDTYPE').val(fvQdbWordType);
      $('#EXTERNALATTACHINFOPATH').val('<%=fvAttachINI%>');

      window.moveTo(100, 100);
      window.resizeTo(1600, 1080);

      $('#f').attr('target', '');
      $('#f').attr('action', '<%=fvClientURL%>');
      $('#f').submit();
    }

  }

</Script>
</HEAD>

<BODY>

<form name="f" action="" method="POST" target="GW_GIAN">
  <input type="hidden" id="K"                       name="K"                       value=""/>
  <input type="hidden" id="USERID"                  name="USERID"                  value=""/>
  <input type="hidden" id="FORMID"                  name="FORMID"                  value=""/>
  <input type="hidden" id="WORDTYPE"                name="WORDTYPE"                value=""/>
  <input type="hidden" id="EXTERNALATTACHINFOPATH"  name="EXTERNALATTACHINFOPATH"  value=""/>
</form>
</BODY>
</HTML>