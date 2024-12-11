package rest

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"sync"
	"test-managed-identity/client/config"

	"github.com/bloodhoundad/azurehound/v2/constants"
)

type AuthClient interface {
	Authenticate(sendFunc sendFunctionType) error // Authenticates the client
	AuthenticateRequest(req *http.Request, sendFunc func(*http.Request) (*http.Response, error)) (*http.Request, error) // Authenticates the client
	CreateAuthRequest(api url.URL) (*http.Request, error) // Performs authentication for the resource
	DecodeAuthResponse(resp *http.Response) error // Decodes the response from the authentication request
}

type ManagedIdentityAuthClient struct {
	AuthClient
	config config.Config
	authUrl url.URL
	api url.URL
}

type GenericAuthClient struct {
	AuthClient
	config config.Config
	api url.URL
	authUrl url.URL
	jwt           string
	clientId      string
	clientSecret  string
	clientCert    string
	clientKey     string
	clientKeyPass string
	username      string
	password      string
	refreshToken  string
	tenant        string
	token         Token
	mutex		sync.RWMutex
}

func NewManagedIdentityAuthClient(config config.Config, auth *url.URL, api *url.URL, http *http.Client) *ManagedIdentityAuthClient {
	return &ManagedIdentityAuthClient{config: config,
		authUrl: *auth,
		api: *api,
	}
}

func NewGenericAuthClient(config config.Config, auth *url.URL, api *url.URL) *GenericAuthClient {
	return &GenericAuthClient{config: config,
		authUrl: *auth,
		api: *api,
		jwt: config.JWT,
		clientId: config.ApplicationId,
		clientSecret: config.ClientSecret,
		clientCert: config.ClientCert,
		clientKey: config.ClientKey,
		clientKeyPass: config.ClientKeyPass,
		username: config.Username,
		password: config.Password,
		refreshToken: config.RefreshToken,
		tenant: config.Tenant,
		token: Token{},
		mutex: sync.RWMutex{},
	}
}

// declare send function as type
type sendFunctionType func(*http.Request) (*http.Response, error)

func (s *GenericAuthClient) Authenticate(sendFunc sendFunctionType) error {
	// Authenticator creates authentication request
	var authReq *http.Request
	if req, err := s.CreateAuthRequest(s.api); err != nil {
		return err
	} else {
		authReq = req
	}

	// We send it using the http client's send function
	var response *http.Response
	if res, err := sendFunc(authReq); err != nil {
		return err
	} else {
		response = res
	} 

	// Decode the response (lock the mutex for great justice)
	defer response.Body.Close()
	s.mutex.Lock()
	defer s.mutex.Unlock()

	// Authenticator decodes the response
	if err := s.AuthClient.DecodeAuthResponse(response); err != nil {
		return err
	} else {
		return nil
	}
}

func (s *GenericAuthClient) CreateAuthRequest(api url.URL) (*http.Request, error) {
	var (
		path         = url.URL{Path: fmt.Sprintf("/%s/oauth2/v2.0/token", s.tenant)}
		endpoint     = s.authUrl.ResolveReference(&path)
		defaultScope = url.URL{Path: "/.default"}
		scope        = s.api.ResolveReference(&defaultScope)
		body         = url.Values{}
	)
	
	if s.clientId == "" {
		body.Add("client_id", constants.AzPowerShellClientID)
	} else {
		body.Add("client_id", s.clientId)
	}

	body.Add("scope", scope.ResolveReference(&defaultScope).String())

	if s.refreshToken != "" {
		body.Add("grant_type", "refresh_token")
		body.Add("refresh_token", s.refreshToken)
		body.Set("client_id", constants.AzPowerShellClientID)
	} else if s.clientSecret != "" {
		body.Add("grant_type", "client_credentials")
		body.Add("client_secret", s.clientSecret)
	} else if s.clientCert != "" && s.clientKey != "" {
		if clientAssertion, err := NewClientAssertion(endpoint.String(), s.clientId, s.clientCert, s.clientKey, s.clientKeyPass); err != nil {
			return nil, err
		} else {
			body.Add("grant_type", "client_credentials")
			body.Add("client_assertion_type", "urn:ietf:params:oauth:client-assertion-type:jwt-bearer")
			body.Add("client_assertion", clientAssertion)
		}
	} else if s.username != "" && s.password != "" {
		body.Add("grant_type", "password")
		body.Add("username", s.username)
		body.Add("password", s.password)
		body.Set("client_id", constants.AzPowerShellClientID)
	} else {
		return nil, fmt.Errorf("unable to authenticate. no valid credential provided")
	}

	if foo, err := NewRequest(context.Background(), "POST", endpoint, body, nil, nil); err != nil {
		return nil, err
	} else {
		return foo, nil
	}
}

func (s *GenericAuthClient) IsExpired() bool {
	return s.token.IsExpired()

}
func (s *GenericAuthClient) DecodeAuthResponse(resp *http.Response) error {
	if err := json.NewDecoder(resp.Body).Decode(&s.token); err != nil {
		return err
	} else {
		return nil
	}

}

func (s *GenericAuthClient) AuthenticateRequest(req *http.Request, sendFunc func(*http.Request) (*http.Response, error)) (*http.Request, error) {
	if s.jwt != "" {
		if aud, err := ParseAud(s.jwt); err != nil {
			return nil, err
		} else if aud != s.api.String() {
			return nil, fmt.Errorf("invalid audience")
		}
		req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", s.jwt))
	} else {
		if s.IsExpired() {
			if err := s.Authenticate(sendFunc); err != nil {
				return nil, err
			}
		}
		req.Header.Set("Authorization", s.token.String())
	}

	return req, nil

}

