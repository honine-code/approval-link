<%@ page pageEncoding="utf-8"%>
<%@ page import="org.apache.log4j.Logger"%>


<%!
  /* MIS���� ���ǵ� ���� ���� �� ���� ���ڸ��� ���� ��� HAI_QDBINFO ���̺���
     APPRSTATUS, APPRSTATUSPREV �� �ʵ尪�� �÷������.
  * */
  private String getLogSancStatus(String reqSancStatus)
  {
    String wReturn = "";

    if(reqSancStatus == null || reqSancStatus.equals("")) wReturn = "[������°��� ����]";

         if(reqSancStatus.equals("A"))  wReturn = "���";
    else if(reqSancStatus.equals("S"))  wReturn = "����";
    else if(reqSancStatus.equals("E"))  wReturn = "�Ϸ�";
    else if(reqSancStatus.equals("C"))  wReturn = "ȸ��";
    else if(reqSancStatus.equals("C"))  wReturn = "�ݷ�";

    else wReturn = "[��ġ�ϴ� ������� ����]";

    return wReturn;
  }

  /* �׷���� CALL�׼ǿ��� ȣ���Ҷ� �Է��ϴ� ��
     GWTYPE �� �ԷµǴ� ��
  ex) /home/handy8/hip/htdocs/ATWork/qdb/QDB.sh 60 /ATWork/qdb/status.jsp?FORMID=0000000002&EMPCD=$EmpNo$&DEPTCD=$DeptCode$&DOCID=$apprid$&GWTYPE=1-07&MISTYPE=HRM01&STATUS=60&MIS_KEY=$MIS_KEY$
  * */
  private String getLogGWStatus(String reqGWStatus)
  {
    String wReturn = "";

    if(reqGWStatus == null || reqGWStatus.equals("")) wReturn = "[�׷���������°��� ����]";

         if(reqGWStatus.equals("1-01")) wReturn = "�߽źμ�-��� ������";
    else if(reqGWStatus.equals("1-02")) wReturn = "�߽źμ�-��� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("1-03")) wReturn = "�߽źμ�-����� ���� ������";
    else if(reqGWStatus.equals("1-04")) wReturn = "�߽źμ�-����� ���� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("1-05")) wReturn = "�߽źμ�-���� ���� ������";
    else if(reqGWStatus.equals("1-06")) wReturn = "�߽źμ�-���� ���� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("1-07")) wReturn = "�߽źμ�-������� ���� ó�� ��";
    else if(reqGWStatus.equals("1-08")) wReturn = "�߽źμ�-������� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("1-09")) wReturn = "�߽źμ�-�ݼ� ������";
    else if(reqGWStatus.equals("1-10")) wReturn = "�߽źμ�-�ݼ� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("1-11")) wReturn = "�߽źμ�-�߽źμ� �߼� ����";
    else if(reqGWStatus.equals("1-12")) wReturn = "�߽źμ�-�߽źμ� �߼� ��ȣ Ȯ����";
    else if(reqGWStatus.equals("1-13")) wReturn = "�߽źμ�-�߽źμ� �߼� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("1-14")) wReturn = "�߽źμ�-�߽źμ� �߼� ���� ó�� ����";
    else if(reqGWStatus.equals("1-15")) wReturn = "�߽źμ�-�߽źμ� �߼۱� �ݼ� ����";
    else if(reqGWStatus.equals("1-16")) wReturn = "�߽źμ�-�߽źμ� �߼۱� �ݼ� ����";
    else if(reqGWStatus.equals("1-17")) wReturn = "�߽źμ�-�߽źμ� �߼۱� �ݼ� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("1-18")) wReturn = "�߽źμ�-�߽źμ� �߼۱� �ݼ� ���� ó�� ����";
    else if(reqGWStatus.equals("1-19")) wReturn = "�߽źμ�-�߰� ���� ������";
    else if(reqGWStatus.equals("1-20")) wReturn = "�߽źμ�-�߰� ���� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("2-01")) wReturn = "���źμ�-���źμ� ������ �ݼ� ������";
    else if(reqGWStatus.equals("2-02")) wReturn = "���źμ�-���źμ� ������ �ݼ� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("2-03")) wReturn = "���źμ�-��� ������";
    else if(reqGWStatus.equals("2-04")) wReturn = "���źμ�-��� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("2-13")) wReturn = "���źμ�-����� ���� ������";                  // ���źμ���������Ἥ���Ŀ� ������ �߻��ص� �������Ǿ� �߰�.
    else if(reqGWStatus.equals("2-05")) wReturn = "���źμ�-����� ���� ������";
    else if(reqGWStatus.equals("2-06")) wReturn = "���źμ�-����� ���� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("2-07")) wReturn = "���źμ�-���� ���� ������";
    else if(reqGWStatus.equals("2-08")) wReturn = "���źμ�-���� ���� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("2-09")) wReturn = "���źμ�-������� ���� ó�� ��";
    else if(reqGWStatus.equals("2-10")) wReturn = "���źμ�-������� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("2-11")) wReturn = "���źμ�-�ݼ� ������";
    else if(reqGWStatus.equals("2-12")) wReturn = "���źμ�-�ݼ� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("2-14")) wReturn = "���źμ�-�߰� ���� ������";
    else if(reqGWStatus.equals("2-15")) wReturn = "���źμ�-�߰� ���� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("3-01")) wReturn = "����μ�-������ �ݼ� ������";
    else if(reqGWStatus.equals("3-02")) wReturn = "����μ�-������ �ݼ� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("3-03")) wReturn = "����μ�-��� ������";
    else if(reqGWStatus.equals("3-04")) wReturn = "����μ�-��� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("3-05")) wReturn = "����μ�-����� ���� ������";
    else if(reqGWStatus.equals("3-06")) wReturn = "����μ�-����� ���� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("3-07")) wReturn = "����μ�-���� ���� ������";
    else if(reqGWStatus.equals("3-08")) wReturn = "����μ�-���� ���� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("3-09")) wReturn = "����μ�-������� ���� ó�� ��";
    else if(reqGWStatus.equals("3-10")) wReturn = "����μ�-������� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("3-11")) wReturn = "����μ�-�ݼ� ������";
    else if(reqGWStatus.equals("3-12")) wReturn = "����μ�-�ݼ� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("0-01")) wReturn = "���ΰ���-��� ������";
    else if(reqGWStatus.equals("0-02")) wReturn = "���ΰ���-��� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("0-03")) wReturn = "���ΰ���-����� ���� ������";
    else if(reqGWStatus.equals("0-04")) wReturn = "���ΰ���-����� ���� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("0-05")) wReturn = "���ΰ���-���� ���� ������";
    else if(reqGWStatus.equals("0-06")) wReturn = "���ΰ���-���� ���� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("0-07")) wReturn = "���ΰ���-������� ���� ó�� ��";
    else if(reqGWStatus.equals("0-08")) wReturn = "���ΰ���-������� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("0-09")) wReturn = "���ΰ���-�ݼ� ������";
    else if(reqGWStatus.equals("0-10")) wReturn = "���ΰ���-�ݼ� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("0-11")) wReturn = "���ΰ���-�߰� ���� ������";
    else if(reqGWStatus.equals("0-12")) wReturn = "���ΰ���-�߰� ���� ���� ó�� �Ϸ�";
    else if(reqGWStatus.equals("0-70")) wReturn = "��������-ȸ�����ó��";
    else wReturn = "[�׷���������°��� ����]";

    return wReturn;
  }
%>
