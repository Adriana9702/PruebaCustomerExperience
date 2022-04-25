<%@ WebHandler Language="C#" Class="CustomerExperienceApi" %>

using SmartHomeAPI;
using System;
using System.Web;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;
using System.Runtime.Serialization.Json;
using System.Web.Script.Serialization;
using System.Globalization;
using System.Net;
using System.Threading.Tasks;
using System.Threading;
using System.Net.Http;
using System.Web.UI;
using Newtonsoft.Json;
using System.Text.RegularExpressions;

public class CustomerExperienceApi : IHttpHandler
{


    string cryptoKey = "+Lead";

    public void ProcessRequest(HttpContext context)
    {
        HttpRequest httpRequest = context.Request;

        Guid companyId = Guid.Empty;
        string companyCode = "";
        string action = "";

        try
        {
            if (context.Request.QueryString["companyCode"] != null) companyCode = httpRequest.QueryString["companyCode"];
            if (context.Request.QueryString["action"] != null) action = httpRequest.QueryString["action"];
        }
        catch
        {
            List<Error> errores = new List<Error>();
            Error error = new Error();

            error.codigo = 001;
            error.mensaje = "error";
            error.status = "Falta algun parametro (comapnyId o action)";
            error.isValid = 0;

            errores.Add(error);
            context.Response.ContentType = "application/json";
            context.Response.Write(JsonConvert.SerializeObject(errores));
        }

        context.Response.AddHeader("Access-Control-Allow-Origin", "*");

        if (context.Request.HttpMethod == "OPTIONS")
        {
            //These headers are handling the "pre-flight" OPTIONS call sent by the browser
            context.Response.AddHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE");
            context.Response.AddHeader("Access-Control-Allow-Headers", "Content-Type,Token, Accept");
            context.Response.AddHeader("Access-Control-Max-Age", "1728000");
            context.Response.End();
        }

        //Leer todo el contenido enviado, seria el formato JSON
        string response = "";

        if (action == "login")
        {
            try
            {
                StreamReader reader = new StreamReader(HttpContext.Current.Request.InputStream);
                string data = reader.ReadToEnd();

                WebClient webClient = new WebClient();
                webClient.Headers["Content-type"] = "application/json";
                webClient.Encoding = Encoding.UTF8;

                var login = JsonConvert.DeserializeObject<Login>(data);

                if (login.User != "" && login.Password != "" && companyCode != "")
                {
                    NexusDataContext db = new NexusDataContext();

                    TextInfo textInfo = new CultureInfo("es-CO", false).TextInfo;
                    IFormatProvider currentCulture = new System.Globalization.CultureInfo("es-CO", false);
                    var company = db.tblCompanies.Where(c => c.isActive && c.code == companyCode).FirstOrDefault();
                    var prospects = (from a in db.tblProspects.Where(p => p.userName == login.User && p.password == login.Password

                                    && p.companyId == company.companyId && p.isActive == true /*&& p.webAccess == true*/).AsEnumerable()
                                     select new
                                     {
                                         ProspectId = a.prospectId,
                                         IdentificationNumber = a.tblCustomer.identificationNumber,
                                         Probability = a.probability,
                                         Module = a.tblModule.tblProject.name + " - " + a.tblModule.name,
                                         ProjectId = a.tblModule.projectId,
                                         ImageProject = "http://smart-home.com.co/ThumbnailHandler.ashx?imageSource=project&projectId=" + a.tblModule.projectId,
                                         ProjectCode = a.tblModule.tblProject.code,
                                         isValid = 1,
                                     }
                                   );


                    if (prospects.Count() > 0)
                    {
                        context.Response.Write(JsonConvert.SerializeObject(prospects));
                        context.Response.ContentType = "application/json";


                    }
                    else
                    {
                        List<Error> errores = new List<Error>();
                        Error error = new Error();

                        error.status = "El cliente no existe";
                        error.isValid = 0;
                        errores.Add(error);
                        context.Response.ContentType = "application/json";
                        context.Response.Write(JsonConvert.SerializeObject(errores));
                    }


                }
                else
                {
                    List<Error> errores = new List<Error>();
                    Error error = new Error();

                    error.status = "Usuario y/o contraseña incorrectos";
                    error.isValid = 0;
                    errores.Add(error);
                    context.Response.ContentType = "application/json";
                    context.Response.Write(JsonConvert.SerializeObject(errores));
                }

            }
            catch (Exception ex)
            {
                List<Error> errores = new List<Error>();
                Error error = new Error();


                error.status = "La acción no fue de logueo";
                error.isValid = 0;

                errores.Add(error);
                context.Response.ContentType = "application/json";
                context.Response.Write(JsonConvert.SerializeObject(errores));
            };


        }
        else if (action == "getProject")
        {
            if (context.Request.QueryString["companyCode"] != null)
            {


                try
                {
                    StreamReader reader = new StreamReader(HttpContext.Current.Request.InputStream);


                    WebClient webClient = new WebClient();
                    webClient.Headers["Content-type"] = "application/json";
                    webClient.Encoding = Encoding.UTF8;

                    companyCode = httpRequest.QueryString["companyCode"];

                    if (companyCode != null && companyCode != "")
                    {
                        NexusDataContext db = new NexusDataContext();

                        TextInfo textInfo = new CultureInfo("es-CO", false).TextInfo;
                        IFormatProvider currentCulture = new System.Globalization.CultureInfo("es-CO", false);

                        ResultProject projectList = new ResultProject();


                        var projects = (from a in db.tblProjects.Where(p => p.tblCompany.code == companyCode).AsEnumerable()
                                        select new ResultProject.Project
                                        {

                                            projectId = a.projectId,
                                            projectIdEncode = EncodeURL(Crypto.EncryptStringAES(a.projectId.ToString(), cryptoKey)),
                                            code = a.tblCompany.code,
                                            name = a.name,
                                            deliveryDate = null,
                                            deposit = a.depositPercentage,
                                            depositPercentage = a.depositPercentage,
                                            downpaymentPercentage = a.downpaymentPercentage,
                                            payments = a.payments,
                                            description = a.description,
                                            latitude = a.latitude,
                                            longitude = a.longitude,
                                            website = a.webSite,

                                        }
                                       ).ToList();

                        if (projects.Count() > 0)
                        {
                            projectList.project = projects;
                            projectList.returnCode = "Success";
                            projectList.returnDesc = "Exitoso";

                            context.Response.Write(JsonConvert.SerializeObject(projects));
                            context.Response.ContentType = "application/json";
                        }

                        else
                        {
                            List<Error> errores = new List<Error>();
                            Error error = new Error();

                            error.status = "No hay projectos para esta compañia";
                            error.isValid = 0;
                            errores.Add(error);
                            context.Response.ContentType = "application/json";
                            context.Response.Write(JsonConvert.SerializeObject(errores));
                        }

                    }
                    else
                    {
                        List<Error> errores = new List<Error>();
                        Error error = new Error();

                        error.status = "El codigo de la compañia es invalido";
                        error.isValid = 0;
                        errores.Add(error);
                        context.Response.ContentType = "application/json";
                        context.Response.Write(JsonConvert.SerializeObject(errores));
                    }

                }
                catch (Exception ex)
                {
                    List<Error> errores = new List<Error>();
                    Error error = new Error();


                    error.status = "La accion no fue de registro";
                    error.isValid = 0;

                    errores.Add(error);
                    context.Response.ContentType = "application/json";
                    context.Response.Write(JsonConvert.SerializeObject(errores));
                }
            }
        }

        else if (action == "updateAccess")
        {
            try
            {
                StreamReader reader = new StreamReader(HttpContext.Current.Request.InputStream);
                string data = reader.ReadToEnd();

                WebClient webClient = new WebClient();
                webClient.Headers["Content-type"] = "application/json";
                webClient.Encoding = Encoding.UTF8;

                var email = JsonConvert.DeserializeObject<EmailProspect>(data);
                if (email.Email != null && email.Email != "")
                {
                    NexusDataContext db = new NexusDataContext();

                    TextInfo textInfo = new CultureInfo("es-CO", false).TextInfo;
                    IFormatProvider currentCulture = new System.Globalization.CultureInfo("es-CO", false);

                    var company = db.tblCompanies.Where(c => c.isActive && c.code == companyCode).FirstOrDefault();

                    var credentials = db.tblCustomers.Where(a => a.email == email.Email && a.companyId == company.companyId).FirstOrDefault();


                    if (credentials != null)
                    {

                        var customerId = credentials.customerId;
                        var name = credentials.firstName;

                        var prospect = db.tblProspects.Where(c => c.customerId == customerId).AsEnumerable().ToList();

                        Random randNum = new Random();

                        foreach (var j in prospect)
                        {
                            j.userName = name.Replace(" ", "");
                            j.password = Convert.ToString(randNum.Next(1000, 100000));
                            db.SubmitChanges();

                            //string result = "";
                            string mailAccountConfirm = "notificaciones@gaiatelcom.com";
                            string mailPasswordConfirm = "0punkero";
                            string recipientConfirm = email.Email;
                            string mailSubjectConfirm = "Credenciales de ingreso";
                            StringBuilder mailMessageConfirm = new StringBuilder();

                            mailMessageConfirm.Append("<DIV style='max-width: 660px; margin: 0 auto;'>");
                            mailMessageConfirm.Append("<DIV style='padding: 7px 20px 7px 10px;margin: 7px 0;background-color: #fff1a8;font-size: 13px;line-height: 1.3em;color: #555;border: 1px solid #d8d8d8; text-align:center;'>");
                            mailMessageConfirm.Append("<h3>");
                            mailMessageConfirm.Append("❗ Credenciales de ingreso ❗");
                            mailMessageConfirm.Append("</h3>");
                            mailMessageConfirm.Append("<BR>");
                            mailMessageConfirm.Append("Usuario: " + j.userName);
                            mailMessageConfirm.Append("<BR>");
                            mailMessageConfirm.Append("Contraseña: " + j.password);
                            mailMessageConfirm.Append("<BR>");
                            mailMessageConfirm.Append("</DIV>");

                            MailSender mailSenderConfirm = new MailSender("", "", true);
                            //MailSender mailSender = new MailSender(company.smtpServer, company.smtpServerPort.ToString(), company.smtpEnableSSL.Value);
                            if (mailSenderConfirm.SendMail(mailAccountConfirm, mailPasswordConfirm, recipientConfirm, mailSubjectConfirm, mailMessageConfirm.ToString()))
                            {

                            }
                            else
                            {
                            }
                        }

                        var message = "Ya fueron enviadas las credenciales de acceso.";
                        context.Response.Write(JsonConvert.SerializeObject(message));
                        context.Response.ContentType = "application/json";


                    }
                    else
                    {

                        List<Error> errores = new List<Error>();
                        Error error = new Error();

                        error.status = "No hay un usuario con ese correo ";
                        error.isValid = 0;
                        errores.Add(error);
                        context.Response.ContentType = "application/json";
                        context.Response.Write(JsonConvert.SerializeObject(errores));
                    }

                }
                else
                {
                    List<Error> errores = new List<Error>();
                    Error error = new Error();

                    error.status = "correo invalido ";
                    error.isValid = 0;
                    errores.Add(error);
                    context.Response.ContentType = "application/json";
                    context.Response.Write(JsonConvert.SerializeObject(errores));
                }
            }
            catch (Exception ex)
            {
                List<Error> errores = new List<Error>();
                Error error = new Error();

                error.status = "la accion no fue de actualizacion";
                error.isValid = 0;
                errores.Add(error);
                context.Response.ContentType = "application/json";
                context.Response.Write(JsonConvert.SerializeObject(errores));

            }
        }
        else if (action == "commercial")
        {
            try
            {
                StreamReader reader = new StreamReader(HttpContext.Current.Request.InputStream);
                string data = reader.ReadToEnd();

                WebClient webClient = new WebClient();
                webClient.Headers["Content-type"] = "application/json";
                webClient.Encoding = Encoding.UTF8;

                var prospect = JsonConvert.DeserializeObject<Prospect>(data);

                if (prospect.ProspectId != Guid.Empty && prospect.ProspectId != null)
                {
                    NexusDataContext db = new NexusDataContext();

                    TextInfo textInfo = new CultureInfo("es-CO", false).TextInfo;
                    IFormatProvider currentCulture = new System.Globalization.CultureInfo("es-CO", false);

                    var user = (from a in db.tblProspects.Where(b => b.prospectId == prospect.ProspectId).AsEnumerable()
                                select new
                                {
                                    ImageProject = "http://smart-home.com.co/ThumbnailHandler.ashx?imageSource=project&projectId=" + a.tblModule.projectId,
                                    ProjectCode = a.tblModule.tblProject.code,
                                    OwerId = a.ownerId,

                                }).ToArray();


                    if (user.Count() > 0)
                    {
                        context.Response.Write(JsonConvert.SerializeObject(user));
                        context.Response.ContentType = "application/json";


                    }
                    else
                    {
                        List<Error> errores = new List<Error>();
                        Error error = new Error();

                        error.status = "El cliente no existe";
                        error.isValid = 0;
                        errores.Add(error);
                        context.Response.ContentType = "application/json";
                        context.Response.Write(JsonConvert.SerializeObject(errores));
                    }


                }
                else
                {
                    List<Error> errores = new List<Error>();
                    Error error = new Error();

                    error.status = "Id de prospecto invalido";
                    error.isValid = 0;
                    errores.Add(error);
                    context.Response.ContentType = "application/json";
                    context.Response.Write(JsonConvert.SerializeObject(errores));
                }

            }
            catch (Exception ex)
            {
                List<Error> errores = new List<Error>();
                Error error = new Error();


                error.status = "La acción no fue commercial";
                error.isValid = 0;

                errores.Add(error);
                context.Response.ContentType = "application/json";
                context.Response.Write(JsonConvert.SerializeObject(errores));
            };
        }


        else if (action == "updateCredentials")
        {
            try
            {
                StreamReader reader = new StreamReader(HttpContext.Current.Request.InputStream);
                string data = reader.ReadToEnd();

                WebClient webClient = new WebClient();
                webClient.Headers["Content-type"] = "application/json";
                webClient.Encoding = Encoding.UTF8;

                var credentials = JsonConvert.DeserializeObject<Credentials>(data);

                if (credentials.User != null && credentials.User != "" && credentials.Password != null && credentials.Password != "")
                {
                    NexusDataContext db = new NexusDataContext();

                    TextInfo textInfo = new CultureInfo("es-CO", false).TextInfo;
                    IFormatProvider currentCulture = new System.Globalization.CultureInfo("es-CO", false);

                    var AccessCredentials = (from a in db.tblProspects.Where(b => b.prospectId == credentials.ProspectId).AsEnumerable() select a);

                    foreach (var c in AccessCredentials)
                    {
                        c.userName = credentials.User;
                        c.password = credentials.Password;

                        db.SubmitChanges();
                    }
                    var message = "Las credenciales de acceso fueron actualizadas.";
                    context.Response.Write(JsonConvert.SerializeObject(message));
                    context.Response.ContentType = "application/json";
                }
            }
            catch (Exception ex)
            {
                List<Error> errores = new List<Error>();
                Error error = new Error();

                error.status = "La acción no fue de actualización de credenciales.";
                error.isValid = 0;
                errores.Add(error);
                context.Response.ContentType = "application/json";
                context.Response.Write(JsonConvert.SerializeObject(errores));
            }
        }

        else if (action == "imageModule")
        {
            if (context.Request.QueryString["projectId"] != null && context.Request.QueryString["moduleId"] != null)
            {


                try
                {
                    Guid projectId = new Guid(httpRequest.QueryString["projectId"]);
                    Guid moduleId = new Guid(httpRequest.QueryString["moduleId"]);

                    var iamge = GetInfoProjects(projectId, moduleId);
                    context.Response.ContentType = "application/json";
                    context.Response.Write(JsonConvert.SerializeObject(iamge));


                }
                catch (Exception ex)
                {
                    List<Error> errores = new List<Error>();
                    Error error = new Error();


                    error.status = "No hay imagenes disponibles, debe configurar ofertas inteligentes";
                    error.isValid = 0;

                    errores.Add(error);
                    context.Response.ContentType = "application/json";
                    context.Response.Write(JsonConvert.SerializeObject(errores));
                }
            }
        }


        else if (action == "getCustomerSales")
        {
            if (context.Request.QueryString["companyCode"] != null && context.Request.QueryString["identificationNumber"] != null)
            {


                NexusDataContext db = new NexusDataContext();
                db.CommandTimeout = 0;
                try
                {
                    companyCode = httpRequest.QueryString["companyCode"];
                    var identificationNumber = httpRequest.QueryString["identificationNumber"];

                    StreamReader reader = new StreamReader(HttpContext.Current.Request.InputStream);

                    WebClient webClient = new WebClient();
                    webClient.Headers["Content-type"] = "application/json";
                    webClient.Encoding = Encoding.UTF8;

                    var company = db.tblCompanies.Where(c => c.isActive && c.code == companyCode).FirstOrDefault();

                    if (company != null)
                    {


                        TextInfo textInfo = new CultureInfo("es-CO", false).TextInfo;
                        IFormatProvider currentCulture = new System.Globalization.CultureInfo("es-CO", false);

                        ProspectResponse prospectList = new ProspectResponse();

                        var prospects = (from p in db.tblProspects.Where(p => p.probability == 100
                                                && p.isActive
                                                && p.tblCustomer.identificationNumber.Replace(",", "").Replace(".", "").Replace("-", "").Replace(" ", "")
                                                    == identificationNumber.Replace(",", "").Replace(".", "").Replace("-", "").Replace(" ", "")
                                                && p.companyId == company.companyId)
                                         select p);

                        foreach (var prospect in prospects)
                        {
                            var prospects2 = (from p in db.tblProspects.Where(p => p.prospectId == prospect.prospectId).ToArray()
                                              select new ProspectResponse.Prospect
                                              {
                                                  moduleId = p.tblModule.moduleId,
                                                  projectId = p.tblModule.projectId,
                                                  prospectId = p.prospectId,
                                                  customerId = p.customerId,
                                                  ownerId = p.ownerId,
                                                  sellerId = p.sellerId,
                                                  saleCycleId = p.tblStage.stageId,
                                                  stageId = p.tblStage.stageId,
                                                  module = p.tblModule.name,
                                                  project = p.tblModule.tblProject.name,
                                                  projectCode = p.tblModule.tblProject.code,
                                                  offerPrice = p.offerPrice ?? 0,
                                                  totalValue = p.totalValue,
                                                  discount = p.discount ?? 0,
                                                  financialDiscount = p.financialDiscount ?? 0,
                                                  financialCost = p.financialCost ?? 0,
                                                  totalDiscount = p.discountValue,
                                                  deposit = p.deposit ?? 0,
                                                  percentageDeposit = p.depositPercentage,
                                                  downpayment = p.downpayment ?? 0,
                                                  percentageDownpayment = p.downpaymentPercentage,
                                                  firstName = p.tblCustomer.firstName,
                                                  lastName = p.tblCustomer.lastName,
                                                  identificationNumber = p.tblCustomer.identificationNumber,
                                                  email = p.tblCustomer.email,
                                                  phoneNumber = p.tblCustomer.phoneNumber,
                                                  mobileNumber = p.tblCustomer.mobileNumber,
                                                  webAccessPassword = p.password,
                                                  webAccessUserName = p.userName,
                                                  stageName = p.tblStage.name,
                                                  saleCycleName = p.tblStage.tblSaleCycle.name,
                                                  agreementNumber = p.agreementNumber,
                                                  deedDate = p.deedDate,
                                                  handoverDate = p.tblModule.handoverDate,
                                                  probability = p.probability,
                                                  scoring = p.tblCustomer.scoring ?? 0,
                                                  closeDate = p.closeDate,
                                                  createdDate = p.createdDate,
                                                  moduleGarages = (from g in p.tblModule.tblGarageModules
                                                                   select new ProspectResponse.Garage
                                                                   {
                                                                       garageId = g.garageId,
                                                                       name = g.tblGarage.name,
                                                                       price = g.tblGarage.tblGaragePrices.OrderByDescending(gp => gp.date).FirstOrDefault() != null
                                                                       ? g.tblGarage.tblGaragePrices.OrderByDescending(gp => gp.date).FirstOrDefault().price : 0,
                                                                   }).ToArray(),
                                                  moduleStorages = (from s in p.tblModule.tblStorageModules
                                                                    select new ProspectResponse.Storage
                                                                    {
                                                                        storageId = s.storageId,
                                                                        name = s.tblStorage.name,
                                                                        price = s.tblStorage.tblStoragePrices.OrderByDescending(sp => sp.date).FirstOrDefault() != null
                                                                        ? s.tblStorage.tblStoragePrices.OrderByDescending(sp => sp.date).FirstOrDefault().price : 0,
                                                                    }).ToArray(),
                                                  prospectFeatures = (from f in p.tblProspectFeatures
                                                                      select new ProspectResponse.Feature
                                                                      {
                                                                          featureId = f.featureId,
                                                                          name = f.tblFeature.name,
                                                                          price = f.price,
                                                                          quantity = f.quantity
                                                                      }).ToArray(),
                                                  prospectAdjustments = (from a in p.tblProspectAdjustments
                                                                         select new ProspectResponse.Adjustment
                                                                         {
                                                                             adjustmentId = a.adjustmentId,
                                                                             name = a.name,
                                                                             price = a.price
                                                                         }).ToArray(),
                                                  quotedGarages = (from g in p.tblProspectGarages
                                                                   select new ProspectResponse.Garage
                                                                   {
                                                                       garageId = g.garageId,
                                                                       name = g.tblGarage.name,
                                                                       price = g.tblGarage.tblGaragePrices.OrderByDescending(gp => gp.date).FirstOrDefault() != null
                                                                       ? g.tblGarage.tblGaragePrices.OrderByDescending(gp => gp.date).FirstOrDefault().price : 0,
                                                                   }).ToArray(),
                                                  quotedStorages = (from s in p.tblProspectStorages
                                                                    select new ProspectResponse.Storage
                                                                    {
                                                                        storageId = s.storageId,
                                                                        name = s.tblStorage.name,
                                                                        price = s.tblStorage.tblStoragePrices.OrderByDescending(sp => sp.date).FirstOrDefault() != null
                                                                        ? s.tblStorage.tblStoragePrices.OrderByDescending(sp => sp.date).FirstOrDefault().price : 0,
                                                                    }).ToArray(),
                                                  reservation = (from r in p.tblModuleReservations.Where(mr => mr.status == 1
                                                                 && mr.endDate.Date >= DateTime.Today)
                                                                 select new ProspectResponse.Reservation
                                                                 {
                                                                     startDate = r.startDate,
                                                                     endDate = r.endDate,
                                                                     type = r.reservationType,
                                                                 }).ToArray(),
                                                  files = (from d in p.tblProspectFiles
                                                           select new ProspectResponse.Files
                                                           {
                                                               prospectFileId = d.prospectFileId,
                                                               title = d.name,
                                                               tags = (from t in d.tblProspectFileTags
                                                                       select new ProspectResponse.Files.Tag
                                                                       {
                                                                           tagId = t.tblFileTag.fileTagId,
                                                                           name = t.tblFileTag.name,
                                                                       }).ToArray()
                                                           }).ToArray(),
                                                  documents = new List<ProspectResponse.Documents>().ToArray(),

                                                  prospectCustomFields = (from c in p.tblProspectCustomFields
                                                                          select new ProspectResponse.CustomField
                                                                          {
                                                                              customFieldId = c.customFieldId,
                                                                              name = c.tblCustomField.name,
                                                                              value = c.value
                                                                          }).ToArray(),
                                                  customerCustomFields = (from c in p.tblCustomer.tblCustomerCustomFields
                                                                          select new ProspectResponse.CustomField
                                                                          {
                                                                              customFieldId = c.customFieldId,
                                                                              name = c.tblCustomField.name,
                                                                              value = c.value
                                                                          }).ToArray()
                                              }).ToArray();
                            prospectList.prospects = prospects2;
                            prospectList.returnCode = "Success";
                            prospectList.returnDesc = "Exitoso";

                        }

                        if (prospectList.prospects.Count() > 0)
                        {


                            context.Response.Write(JsonConvert.SerializeObject(prospectList));
                            context.Response.ContentType = "application/json";


                        }
                        else
                        {
                            List<Error> errores = new List<Error>();
                            Error error = new Error();

                            error.status = "No se generaron resultados";
                            error.isValid = 0;
                            errores.Add(error);
                            context.Response.ContentType = "application/json";
                            context.Response.Write(JsonConvert.SerializeObject(errores));
                        }
                    }
                    else
                    {
                        List<Error> errores = new List<Error>();
                        Error error = new Error();

                        error.status = "Código entidad no valido";
                        error.isValid = 0;
                        errores.Add(error);
                        context.Response.ContentType = "application/json";
                        context.Response.Write(JsonConvert.SerializeObject(errores));
                    }
                }
                catch (Exception ex)
                {

                }
            }
        }

        else if (action == "Task")
        {
            if (context.Request.QueryString["prospectId"] != null)
            {
                try
                {
                    Guid prospectId = new Guid(httpRequest.QueryString["prospectId"]);
                    StreamReader reader = new StreamReader(HttpContext.Current.Request.InputStream);


                    WebClient webClient = new WebClient();
                    webClient.Headers["Content-type"] = "application/json";
                    webClient.Encoding = Encoding.UTF8;

                    if (prospectId != Guid.Empty && prospectId != null)
                    {
                        NexusDataContext db = new NexusDataContext();

                        TextInfo textInfo = new CultureInfo("es-CO", false).TextInfo;
                        IFormatProvider currentCulture = new System.Globalization.CultureInfo("es-CO", false);

                        //Task taskList = new Task();

                        var task = db.tblProspectTasks.Where(r => r.prospectId == prospectId).ToArray();

                        if (task != null)
                        {
                            var taskDetail = (from c in task.Where(t => t.tblCompanyTask.isMilestone == true).AsEnumerable()
                                              group c by new /*Task.taskDetail*/
                                              {
                                                  taskList = c.tblProspectTaskList.tblCompanyTaskList.name,
                                              } into cg
                                              select new /*Task.taskDetail.ResultTask*/
                                              {
                                                  TaskList = cg.Key.taskList.ToUpper(),
                                                  ProspectTasks = (from pt in cg.AsEnumerable()
                                                                   select new /*Task.taskDetail.ResultTask.prospectTask*/
                                                                   {
                                                                       ProspectId = pt.prospectId,
                                                                       CompanyTask = pt.tblCompanyTask.name ?? "",
                                                                       ScheduleDateFormat = pt.scheduledDate.Date,
                                                                       ScheduleDate = pt.scheduledDate.ToShortDateString(),
                                                                       StartDate = pt.startDate != null ? pt.startDate.Value.ToShortDateString() : "",
                                                                       EndDate = pt.endDate != null ? pt.endDate.Value.ToShortDateString() : "",
                                                                       Comments = pt.comments ?? "",
                                                                   }).OrderByDescending(o => o.ScheduleDateFormat).ToList(),
                                              }).ToList();

                            if (taskDetail.Count() > 0)
                            {

                                //taskList.TaskDetail = taskDetail;

                                context.Response.Write(JsonConvert.SerializeObject(taskDetail));
                                context.Response.ContentType = "application/json";


                            }
                            else
                            {
                                List<Error> errores = new List<Error>();
                                Error error = new Error();

                                error.status = "No hay trámites activos";
                                error.isValid = 0;
                                errores.Add(error);
                                context.Response.ContentType = "application/json";
                                context.Response.Write(JsonConvert.SerializeObject(errores));
                            }
                        }
                        else
                        {
                            List<Error> errores = new List<Error>();
                            Error error = new Error();

                            error.status = "El cliente no tiene trámites";
                            error.isValid = 0;
                            errores.Add(error);
                            context.Response.ContentType = "application/json";
                            context.Response.Write(JsonConvert.SerializeObject(errores));
                        }
                    }

                }
                catch (Exception ex)
                {

                }
            }
        }
        else if (action == "getClaimId")
        {
            if (context.Request.QueryString["moduleId"] != null)
            {


                try
                {
                    Guid moduleId = new Guid(httpRequest.QueryString["moduleId"]);
                    //Guid projectId = new Guid(httpRequest.QueryString["projectId"]);
                    //companyCode = httpRequest.QueryString["companyCode"];
                    StreamReader reader = new StreamReader(HttpContext.Current.Request.InputStream);

                    WebClient webClient = new WebClient();
                    webClient.Headers["Content-type"] = "application/json";
                    webClient.Encoding = Encoding.UTF8;

                    if (moduleId != Guid.Empty && moduleId != null)
                    {
                        NexusDataContext db = new NexusDataContext();
                        db.CommandTimeout = 0;
                        TextInfo textInfo = new CultureInfo("es-CO", false).TextInfo;
                        IFormatProvider currentCulture = new System.Globalization.CultureInfo("es-CO", false);

                        var claimsId = (from b in db.tblClaims.Where(c => c.moduleId == moduleId)
                                        select new
                                        {
                                            ClaimId = b.claimId,
                                            date = b.createdDate,
                                        }

                                      ).ToList().OrderByDescending(s => s.date);

                        if (claimsId.Count() > 0)
                        {
                            context.Response.Write(JsonConvert.SerializeObject(claimsId));
                            context.Response.ContentType = "application/json";
                        }
                        else
                        {
                            List<Error> errores = new List<Error>();
                            Error error = new Error();

                            error.status = "El modulo no tiene postventas asociadas";
                            error.isValid = 0;
                            errores.Add(error);
                            context.Response.ContentType = "application/json";
                            context.Response.Write(JsonConvert.SerializeObject(errores));


                        }

                    }
                }
                catch (Exception ex)
                {
                    List<Error> errores = new List<Error>();
                    Error error = new Error();

                    error.status = "El modulo no tiene postventas asociadas";
                    error.isValid = 0;
                    errores.Add(error);
                    context.Response.ContentType = "application/json";
                    context.Response.Write(JsonConvert.SerializeObject(errores));
                }
            }
        }
        else if (action == "getCompany")
        {
            if (context.Request.QueryString["companyCode"] != null)
            {
                try
                {
                    companyCode = httpRequest.QueryString["companyCode"];
                    NexusDataContext db = new NexusDataContext();
                    StreamReader reader = new StreamReader(HttpContext.Current.Request.InputStream);

                    WebClient webClient = new WebClient();
                    webClient.Headers["Content-type"] = "application/json";
                    webClient.Encoding = Encoding.UTF8;

                    var existingCompany = db.tblCompanies.Where(c => c.code == companyCode).FirstOrDefault();
                    if (existingCompany != null)
                    {
                        TextInfo textInfo = new CultureInfo("es-CO", false).TextInfo;
                        IFormatProvider currentCulture = new System.Globalization.CultureInfo("es-CO", false);

                        CompanyResponse companyDetail = new CompanyResponse();

                        var company = (from c in db.tblCompanies.Where(c => c.isActive && c.code == companyCode)
                                       select new CompanyResponse.Company
                                       {
                                           companyId = c.companyId,
                                           name = c.name,
                                           email = c.email,
                                           phoneNumber = c.phoneNumber,
                                           address = c.address,
                                       }).ToArray();

                        companyDetail.company = company;
                        companyDetail.returnCode = "Success";
                        companyDetail.returnDesc = "Exitoso";

                        if (companyDetail.company.Count() > 0)
                        {
                            context.Response.Write(JsonConvert.SerializeObject(companyDetail));
                            context.Response.ContentType = "application/json";
                        }
                        else
                        {
                            List<Error> errores = new List<Error>();
                            Error error = new Error();

                            error.status = "No hay datos de la compañia";
                            error.isValid = 0;
                            errores.Add(error);
                            context.Response.ContentType = "application/json";
                            context.Response.Write(JsonConvert.SerializeObject(errores));


                        }
                    }
                    else
                    {
                        List<Error> errores = new List<Error>();
                        Error error = new Error();

                        error.status = "Codigo de compañia incorrecto";
                        error.isValid = 0;
                        errores.Add(error);
                        context.Response.ContentType = "application/json";
                        context.Response.Write(JsonConvert.SerializeObject(errores));
                    }

                }
                catch (Exception ex)
                {
                    List<Error> errores = new List<Error>();
                    Error error = new Error();

                    error.status = "Falla técnica resolviendo la petición.";
                    error.isValid = 0;
                    errores.Add(error);
                    context.Response.ContentType = "application/json";
                    context.Response.Write(JsonConvert.SerializeObject(errores));

                }
            }
        }

    }



    #region helpers
    public List<string> GetInfoProjects(Guid projectId, Guid moduleId)
    {
        List<string> result = new List<string>();

        NexusDataContext db = new NexusDataContext();

        TextInfo textInfo = new CultureInfo("es-CO", false).TextInfo;
        IFormatProvider currentCulture = new System.Globalization.CultureInfo("es-CO", false);

        tblModule module = db.tblModules.Where(s => s.moduleId == moduleId).FirstOrDefault();

        string customField = db.tblProjectCustomFields.Where(pr => pr.projectId == projectId
                  && pr.tblCustomField.isActive
                  && pr.tblCustomField.name == "QuotationSettings").FirstOrDefault().value;
        System.Web.Script.Serialization.JavaScriptSerializer serializer = new System.Web.Script.Serialization.JavaScriptSerializer();
        if (customField != null)
        {
            var jsonData = JsonConvert.DeserializeObject<DataSettings>(customField);



            if (jsonData != null)
            {
                var moduleData = module.tblModuleDetail.type;
                if (jsonData.clasification == "tipo") moduleData = module.tblModuleDetail.type.ToString();
                else if (jsonData.clasification == "area") moduleData = module.tblModuleDetail.area.ToString();
                else if (jsonData.clasification == "inmueble") moduleData = module.name;
                else if (jsonData.clasification == "piso") moduleData = module.floor.ToString();
                else if (jsonData.clasification == "") moduleData = module.floor.ToString();

                result = jsonData.detailClasification.Where(s => s.name == moduleData).FirstOrDefault().images;
            }

        }
        else
        {
            result.Add("Debe configurar ofertas inteligentes");
        }
        return result;
    }

    #endregion helpers


    public bool IsReusable
    {
        get
        {
            return true;
        }
    }

    #region clases

    public class DataSettings
    {
        public string companycode { get; set; }
        public string projectCode { get; set; }
        public string clasification { get; set; }
        public string paymentSource { get; set; }
        public List<string> projectImages { get; set; }
        public List<DetailClasification> detailClasification { get; set; }
        public string video { get; set; }
        public string virtualTour { get; set; }
        public string aditionalInfo { get; set; }
        public string contactPhone { get; set; }
        public string whatsappMessage { get; set; }
        public string rawHtml { get; set; }
        public Reservation reservation { get; set; }
        public Visits visits { get; set; }

        public class DetailClasification
        {
            public string name { get; set; }
            public string descrition_Clasification { get; set; }
            public List<string> characteristicList { get; set; }
            public List<string> images { get; set; }
        }

        public class Reservation
        {
            public bool reservationISactive { get; set; }
            public int reservationDays { get; set; }
        }

        public class Visits
        {
            public bool visitsIsActive { get; set; }
        }
    }

    public class Login
    {
        public string User { get; set; }
        public string Password { get; set; }
    }
    public class Credentials
    {
        public string User { get; set; }
        public string Password { get; set; }
        public Guid ProspectId { get; set; }
    }
    public class Prospect
    {
        public Guid ProspectId { get; set; }
        public string User { get; set; }
        public string Password { get; set; }

    }

    public class Error
    {
        public int codigo { get; set; }
        public string mensaje { get; set; }
        public string status { get; set; }
        public int isValid { get; set; }
    }

    public class ResultProject
    {
        public string returnCode { get; set; }
        public string returnDesc { get; set; }
        public List<Project> project { get; set; }

        public class Project
        {
            public Guid projectId { get; set; }
            public string projectIdEncode { get; set; }
            public string code { get; set; }
            public string name { get; set; }
            public DateTime? deliveryDate { get; set; }
            public decimal? deposit { get; set; }
            public decimal? depositPercentage { get; set; }
            public decimal? downpaymentPercentage { get; set; }
            public int? payments { get; set; }
            public string description { get; set; }
            public decimal latitude { get; set; }
            public decimal longitude { get; set; }
            public string website { get; set; }
        }
    }



    public class Task
    {
        public string TaskList { get; set; }
        public List<ProspectTask> ProspectTasks { get; set; }

        public class ProspectTask
        {
            public string ProspectId { get; set; }
            public string CompanyTask { get; set; }
            public DateTime ScheduleDateFormat { get; set; }
            public string ScheduleDate { get; set; }
            public string StartDate { get; set; }
            public string EndDate { get; set; }
            public string Comments { get; set; }
        }
    }

    public class Claims
    {

        public string claimId { get; set; }
        public string createdDate { get; set; }
    }

    public class EmailProspect
    {
        public string Email { get; set; }

    }
    public class ProspectResponse
    {
        public Prospect[] prospects { get; set; }
        public string serviceCode { get; set; }
        public string returnCode { get; set; }
        public string returnDesc { get; set; }

        public class Prospect
        {
            public Guid moduleId { get; set; }
            public Guid projectId { get; set; }
            public Guid prospectId { get; set; }
            public Guid customerId { get; set; }
            public Guid saleCycleId { get; set; }
            public Guid stageId { get; set; }
            public Guid ownerId { get; set; }
            public Guid? sellerId { get; set; }
            public string projectCode { get; set; }
            public string module { get; set; }
            public string project { get; set; }
            public decimal offerPrice { get; set; }
            public decimal totalValue { get; set; }
            public decimal discount { get; set; }
            public decimal financialDiscount { get; set; }
            public decimal financialCost { get; set; }
            public decimal totalDiscount { get; set; }
            public decimal deposit { get; set; }
            public decimal percentageDeposit { get; set; }
            public decimal downpayment { get; set; }
            public decimal percentageDownpayment { get; set; }
            public string firstName { get; set; }
            public string lastName { get; set; }
            public string identificationNumber { get; set; }
            public string email { get; set; }
            public string phoneNumber { get; set; }
            public string mobileNumber { get; set; }
            public string webAccessUserName { get; set; }
            public string webAccessPassword { get; set; }
            public int probability { get; set; }
            public int scoring { get; set; }
            public string saleCycleName { get; set; }
            public string stageName { get; set; }
            public string agreementNumber { get; set; }
            public DateTime? deedDate { get; set; }
            public DateTime? createdDate { get; set; }
            public DateTime? closeDate { get; set; }
            public DateTime? handoverDate { get; set; }
            public Garage[] moduleGarages { get; set; }
            public Storage[] moduleStorages { get; set; }
            public Garage[] quotedGarages { get; set; }
            public Storage[] quotedStorages { get; set; }
            public Feature[] prospectFeatures { get; set; }
            public Adjustment[] prospectAdjustments { get; set; }
            public Reservation[] reservation { get; set; }
            public Files[] files { get; set; }
            public Documents[] documents { get; set; }
            public CustomField[] prospectCustomFields { get; set; }
            public CustomField[] customerCustomFields { get; set; }
        }

        public class Reservation
        {
            public DateTime startDate { get; set; }
            public DateTime endDate { get; set; }
            public int type { get; set; }
        }

        public class Garage
        {
            public Guid garageId { get; set; }
            public string name { get; set; }
            public decimal price { get; set; }
            public int status { get; set; }
        }

        public class Storage
        {
            public Guid storageId { get; set; }
            public string name { get; set; }
            public decimal price { get; set; }
            public int status { get; set; }
        }

        public class Feature
        {
            public Guid featureId { get; set; }
            public string name { get; set; }
            public decimal price { get; set; }
            public int quantity { get; set; }
        }

        public class Adjustment
        {
            public Guid adjustmentId { get; set; }
            public string name { get; set; }
            public decimal price { get; set; }
        }

        public class Files
        {
            public Guid prospectFileId { get; set; }
            public string title { get; set; }
            public string path { get; set; }
            public Tag[] tags { get; set; }

            public class Tag
            {
                public Guid tagId { get; set; }
                public string name { get; set; }
            }
        }

        public class Documents
        {
            public Guid documentRepositoryId { get; set; }
            public string title { get; set; }
            public string content { get; set; }
            public DateTime date { get; set; }
        }

        public class CustomField
        {
            public Guid customFieldId { get; set; }
            public string name { get; set; }
            public string value { get; set; }
        }
    }
    public class CompanyResponse
    {
        public Company[] company { get; set; }
        public string serviceCode { get; set; }
        public string returnCode { get; set; }
        public string returnDesc { get; set; }

        public class Company
        {
            public Guid companyId { get; set; }
            public string name { get; set; }
            public string phoneNumber { get; set; }
            public string address { get; set; }
            public string email { get; set; }
        }


    }

    #endregion clases
    protected string EncodeURL(string base64)
    {
        string code = base64.Replace('+', '-');
        code = code.Replace('=', '_');

        return code;
    }

    protected string DecodeURL(string base64)
    {
        string code = base64.Replace('-', '+');
        code = code.Replace('_', '=');

        return code;
    }

}