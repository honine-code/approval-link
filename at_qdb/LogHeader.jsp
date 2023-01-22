<%@ page pageEncoding="utf-8"%>
<%@ page import="org.apache.log4j.Logger"%>


<%!
  /* MIS와의 정의된 값에 따라 값 변경 두자리가 넘을 경우 HAI_QDBINFO 테이블의
     APPRSTATUS, APPRSTATUSPREV 두 필드값을 늘려줘야함.
  * */
  private String getLogSancStatus(String reqSancStatus)
  {
    String wReturn = "";

    if(reqSancStatus == null || reqSancStatus.equals("")) wReturn = "[결재상태값이 없음]";

         if(reqSancStatus.equals("A"))  wReturn = "등록";
    else if(reqSancStatus.equals("S"))  wReturn = "진행";
    else if(reqSancStatus.equals("E"))  wReturn = "완료";
    else if(reqSancStatus.equals("C"))  wReturn = "회수";
    else if(reqSancStatus.equals("C"))  wReturn = "반려";

    else wReturn = "[일치하는 결재상태 없음]";

    return wReturn;
  }

  /* 그룹웨어 CALL액션에서 호출할때 입력하는 값
     GWTYPE 에 입력되는 값
  ex) /home/handy8/hip/htdocs/ATWork/qdb/QDB.sh 60 /ATWork/qdb/status.jsp?FORMID=0000000002&EMPCD=$EmpNo$&DEPTCD=$DeptCode$&DOCID=$apprid$&GWTYPE=1-07&MISTYPE=HRM01&STATUS=60&MIS_KEY=$MIS_KEY$
  * */
  private String getLogGWStatus(String reqGWStatus)
  {
    String wReturn = "";

    if(reqGWStatus == null || reqGWStatus.equals("")) wReturn = "[그룹웨어결재상태값이 없음]";

         if(reqGWStatus.equals("1-01")) wReturn = "발신부서-기안 서명후";
    else if(reqGWStatus.equals("1-02")) wReturn = "발신부서-기안 서버 처리 완료";
    else if(reqGWStatus.equals("1-03")) wReturn = "발신부서-기안자 전결 서명후";
    else if(reqGWStatus.equals("1-04")) wReturn = "발신부서-기안자 전결 서버 처리 완료";
    else if(reqGWStatus.equals("1-05")) wReturn = "발신부서-최종 결재 서명후";
    else if(reqGWStatus.equals("1-06")) wReturn = "발신부서-최종 결재 서버 처리 완료";
    else if(reqGWStatus.equals("1-07")) wReturn = "발신부서-결재취소 서버 처리 전";
    else if(reqGWStatus.equals("1-08")) wReturn = "발신부서-결재취소 서버 처리 완료";
    else if(reqGWStatus.equals("1-09")) wReturn = "발신부서-반송 서명후";
    else if(reqGWStatus.equals("1-10")) wReturn = "발신부서-반송 서버 처리 완료";
    else if(reqGWStatus.equals("1-11")) wReturn = "발신부서-발신부서 발송 직전";
    else if(reqGWStatus.equals("1-12")) wReturn = "발신부서-발신부서 발송 암호 확인후";
    else if(reqGWStatus.equals("1-13")) wReturn = "발신부서-발신부서 발송 서버 처리 완료";
    else if(reqGWStatus.equals("1-14")) wReturn = "발신부서-발신부서 발송 서버 처리 실패";
    else if(reqGWStatus.equals("1-15")) wReturn = "발신부서-발신부서 발송기 반송 직전";
    else if(reqGWStatus.equals("1-16")) wReturn = "발신부서-발신부서 발송기 반송 직후";
    else if(reqGWStatus.equals("1-17")) wReturn = "발신부서-발신부서 발송기 반송 서버 처리 완료";
    else if(reqGWStatus.equals("1-18")) wReturn = "발신부서-발신부서 발송기 반송 서버 처리 실패";
    else if(reqGWStatus.equals("1-19")) wReturn = "발신부서-중간 결재 서명후";
    else if(reqGWStatus.equals("1-20")) wReturn = "발신부서-중간 결재 서버 처리 완료";
    else if(reqGWStatus.equals("2-01")) wReturn = "수신부서-수신부서 접수기 반송 서명후";
    else if(reqGWStatus.equals("2-02")) wReturn = "수신부서-수신부서 접수기 반송 서버 처리 완료";
    else if(reqGWStatus.equals("2-03")) wReturn = "수신부서-기안 서명후";
    else if(reqGWStatus.equals("2-04")) wReturn = "수신부서-기안 서버 처리 완료";
    else if(reqGWStatus.equals("2-13")) wReturn = "수신부서-기안자 전결 서명전";                  // 수신부서기안자전결서명후에 오류가 발생해도 계속진행되어 추가.
    else if(reqGWStatus.equals("2-05")) wReturn = "수신부서-기안자 전결 서명후";
    else if(reqGWStatus.equals("2-06")) wReturn = "수신부서-기안자 전결 서버 처리 완료";
    else if(reqGWStatus.equals("2-07")) wReturn = "수신부서-최종 결재 서명후";
    else if(reqGWStatus.equals("2-08")) wReturn = "수신부서-최종 결재 서버 처리 완료";
    else if(reqGWStatus.equals("2-09")) wReturn = "수신부서-결재취소 서버 처리 전";
    else if(reqGWStatus.equals("2-10")) wReturn = "수신부서-결재취소 서버 처리 완료";
    else if(reqGWStatus.equals("2-11")) wReturn = "수신부서-반송 서명후";
    else if(reqGWStatus.equals("2-12")) wReturn = "수신부서-반송 서버 처리 완료";
    else if(reqGWStatus.equals("2-14")) wReturn = "수신부서-중간 결재 서명후";
    else if(reqGWStatus.equals("2-15")) wReturn = "수신부서-중간 결재 서버 처리 완료";
    else if(reqGWStatus.equals("3-01")) wReturn = "감사부서-접수기 반송 서명후";
    else if(reqGWStatus.equals("3-02")) wReturn = "감사부서-접수기 반송 서버 처리 완료";
    else if(reqGWStatus.equals("3-03")) wReturn = "감사부서-기안 서명후";
    else if(reqGWStatus.equals("3-04")) wReturn = "감사부서-기안 서버 처리 완료";
    else if(reqGWStatus.equals("3-05")) wReturn = "감사부서-기안자 전결 서명후";
    else if(reqGWStatus.equals("3-06")) wReturn = "감사부서-기안자 전결 서버 처리 완료";
    else if(reqGWStatus.equals("3-07")) wReturn = "감사부서-최종 결재 서명후";
    else if(reqGWStatus.equals("3-08")) wReturn = "감사부서-최종 결재 서버 처리 완료";
    else if(reqGWStatus.equals("3-09")) wReturn = "감사부서-결재취소 서버 처리 전";
    else if(reqGWStatus.equals("3-10")) wReturn = "감사부서-결재취소 서버 처리 완료";
    else if(reqGWStatus.equals("3-11")) wReturn = "감사부서-반송 서명후";
    else if(reqGWStatus.equals("3-12")) wReturn = "감사부서-반송 서버 처리 완료";
    else if(reqGWStatus.equals("0-01")) wReturn = "내부결재-기안 서명후";
    else if(reqGWStatus.equals("0-02")) wReturn = "내부결재-기안 서버 처리 완료";
    else if(reqGWStatus.equals("0-03")) wReturn = "내부결재-기안자 전결 서명후";
    else if(reqGWStatus.equals("0-04")) wReturn = "내부결재-기안자 전결 서버 처리 완료";
    else if(reqGWStatus.equals("0-05")) wReturn = "내부결재-최종 결재 서명후";
    else if(reqGWStatus.equals("0-06")) wReturn = "내부결재-최종 결재 서버 처리 완료";
    else if(reqGWStatus.equals("0-07")) wReturn = "내부결재-결재취소 서버 처리 전";
    else if(reqGWStatus.equals("0-08")) wReturn = "내부결재-결재취소 서버 처리 완료";
    else if(reqGWStatus.equals("0-09")) wReturn = "내부결재-반송 서명후";
    else if(reqGWStatus.equals("0-10")) wReturn = "내부결재-반송 서버 처리 완료";
    else if(reqGWStatus.equals("0-11")) wReturn = "내부결재-중간 결재 서명후";
    else if(reqGWStatus.equals("0-12")) wReturn = "내부결재-중간 결재 서버 처리 완료";
    else if(reqGWStatus.equals("0-70")) wReturn = "결재진행-회수취소처리";
    else wReturn = "[그룹웨어결재상태값이 없음]";

    return wReturn;
  }
%>
