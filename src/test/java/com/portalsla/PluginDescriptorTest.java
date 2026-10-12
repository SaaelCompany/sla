package com.portalsla;

import org.junit.Test;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

import javax.xml.parsers.DocumentBuilderFactory;
import java.io.File;
import java.io.FileInputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

public class PluginDescriptorTest {

    @Test
    public void moduleKeysAreUniqueAcrossModuleTypes() throws Exception {
        File descriptor = new File("target/classes/atlassian-plugin.xml");
        assertTrue("Filtered Atlassian plugin descriptor must exist", descriptor.isFile());

        org.w3c.dom.Document document = DocumentBuilderFactory.newInstance()
                .newDocumentBuilder()
                .parse(descriptor);
        assertEquals("Niout Portal SLA for JSM", document.getDocumentElement().getAttribute("name"));
        NodeList elements = document.getElementsByTagName("*");
        Map<String, String> declarations = new HashMap<String, String>();

        for (int i = 0; i < elements.getLength(); i++) {
            Element element = (Element) elements.item(i);
            String tag = element.getTagName();
            if ("atlassian-plugin".equals(tag) || "label".equals(tag) || !element.hasAttribute("key")) {
                continue;
            }

            String key = element.getAttribute("key");
            String previousTag = declarations.put(key, tag);
            assertNull("Duplicate plugin key '" + key + "' in <" + previousTag + "> and <" + tag + ">",
                    previousTag);
        }
    }

    @Test
    public void russianProjectLinkUsesPropertiesEscapes() throws Exception {
        Properties properties = new Properties();
        FileInputStream in = new FileInputStream("src/main/resources/portal-sla_ru_RU.properties");
        try {
            properties.load(in);
        } finally {
            in.close();
        }
        assertEquals("SLA на портале", properties.getProperty("portal-sla.admin.link"));
    }

    @Test
    public void settingsPageDeclaresProjectAdminContext() throws Exception {
        String shell = read("src/main/resources/templates/settings-shell.html");
        assertTrue(shell.contains("name=\"admin.active.section\" content=\"atl.jira.proj.config\""));
        assertTrue(shell.contains("name=\"projectKey\" content=\"@@PROJECT_KEY@@\""));
        assertTrue(shell.contains("name=\"projectId\" content=\"@@PROJECT_ID@@\""));
        assertTrue(shell.contains("name=\"admin.active.tab\" content=\"portal-sla-admin-link\""));
        String servlet = read("src/main/java/com/portalsla/servlet/EditorServlet.java");
        assertTrue(servlet.contains("@@PROJECT_ID@@"));
        assertTrue(servlet.contains("ServletRequestProjectConfigRequestCache:project"));
        String settings = read("src/main/resources/js/settings.js");
        assertTrue(!settings.contains("psla-portal-frame"));
        assertTrue(!settings.contains("Не работает принтер"));
    }

    private static String read(String path) throws Exception {
        return new String(Files.readAllBytes(Paths.get(path)), StandardCharsets.UTF_8);
    }
}