"""
Adapter responsible for communicating with Technitium DNS Server using
the Technitium HTTP API.
"""

import logging
import requests
from typing import Tuple, Optional, List, Dict
from urllib.parse import urljoin

from .config import get_settings

logger = logging.getLogger(__name__)


class TechnitiumClient:
    """
    Client for Technitium DNS Server HTTP API
    Manages zones and records via Technitium API
    """
    
    def __init__(self, api_url: str, api_token: str):
        """
        Initialize Technitium client
        
        Args:
            api_url: Technitium API URL (e.g., http://192.168.0.53:5380)
            api_token: Technitium API token
        """
        self.api_url = api_url.rstrip('/')
        self.api_token = api_token
        self.session = requests.Session()
        self.session.verify = False  # Allow self-signed certs during migration
        
        logger.info(f"Technitium client initialized for {api_url}")
    
    def _request(self, method: str, endpoint: str, **kwargs) -> requests.Response:
        """Make API request to Technitium"""
        url = urljoin(self.api_url, endpoint)
        
        # Technitium API requires token as query parameter
        params = kwargs.get('params', {})
        params['token'] = self.api_token
        kwargs['params'] = params
        
        # Ensure Content-Type header for JSON requests
        if method in ('POST', 'PUT', 'PATCH'):
            headers = kwargs.get('headers', {})
            if 'Content-Type' not in headers:
                headers['Content-Type'] = 'application/json'
            kwargs['headers'] = headers
        
        response = self.session.request(method, url, **kwargs)
        return response
    
    def create_zone(self, zone_name: str, zone_type: str = 'Primary') -> Tuple[bool, Optional[str]]:
        """
        Create DNS zone in Technitium
        
        Args:
            zone_name: Zone name (e.g., "bakerstreetlabs.io")
            zone_type: Zone type (Primary, Secondary, Stub, Forwarder)
        
        Returns:
            Tuple of (success, error_message)
        """
        try:
            payload = {
                'zone': zone_name.rstrip('.'),
                'type': zone_type
            }
            
            response = self._request('POST', '/api/zones/create', json=payload)
            
            if response.status_code == 200:
                logger.info(f"Zone created: {zone_name}")
                return (True, None)
            elif response.status_code == 409:
                logger.info(f"Zone already exists: {zone_name}")
                return (True, None)  # Already exists is OK
            else:
                error_data = response.json() if response.content else {}
                error = error_data.get('errorMessage', response.text)
                logger.error(f"Failed to create zone: {error}")
                return (False, error)
        
        except Exception as e:
            logger.error(f"Exception creating zone: {e}")
            return (False, str(e))
    
    def add_record(
        self,
        zone: str,
        name: str,
        record_type: str,
        content: str,
        ttl: int = 60
    ) -> Tuple[bool, Optional[str]]:
        """
        Add DNS record to Technitium zone
        
        Args:
            zone: Zone name
            name: Record name (FQDN or relative)
            record_type: Record type (A, AAAA, CNAME, etc.)
            content: Record content
            ttl: TTL in seconds
        
        Returns:
            Tuple of (success, error_message)
        """
        try:
            # Technitium API format
            payload = {
                'zone': zone.rstrip('.'),
                'name': name.rstrip('.'),
                'type': record_type,
                'value': content,
                'ttl': ttl
            }
            
            response = self._request('POST', '/api/zones/records/add', json=payload)
            
            if response.status_code == 200:
                logger.info(f"Record added: {name} ({record_type}) → {content}")
                return (True, None)
            elif response.status_code == 409:
                # Record exists, try to update it
                logger.info(f"Record exists, updating: {name}")
                return self.update_record(zone, name, record_type, content, ttl)
            else:
                error_data = response.json() if response.content else {}
                error = error_data.get('errorMessage', response.text)
                logger.error(f"Failed to add record: {error}")
                return (False, error)
        
        except Exception as e:
            logger.error(f"Exception adding record: {e}")
            return (False, str(e))
    
    def update_record(
        self,
        zone: str,
        name: str,
        record_type: str,
        content: str,
        ttl: int = 60
    ) -> Tuple[bool, Optional[str]]:
        """Update existing DNS record"""
        try:
            # First delete, then add (Technitium may not have direct update)
            delete_result = self.delete_record(zone, name, record_type)
            if not delete_result[0]:
                logger.warning(f"Could not delete existing record, attempting add anyway")
            
            return self.add_record(zone, name, record_type, content, ttl)
        
        except Exception as e:
            logger.error(f"Exception updating record: {e}")
            return (False, str(e))
    
    def delete_record(self, zone: str, name: str, record_type: str) -> Tuple[bool, Optional[str]]:
        """Delete DNS record from Technitium"""
        try:
            payload = {
                'zone': zone.rstrip('.'),
                'name': name.rstrip('.'),
                'type': record_type
            }
            
            response = self._request('POST', '/api/zones/records/delete', json=payload)
            
            if response.status_code == 200:
                logger.info(f"Record deleted: {name} ({record_type})")
                return (True, None)
            else:
                error_data = response.json() if response.content else {}
                error = error_data.get('errorMessage', response.text)
                return (False, error)
        
        except Exception as e:
            logger.error(f"Exception deleting record: {e}")
            return (False, str(e))
    
    def list_zones(self) -> List[Dict]:
        """List all zones on Technitium server"""
        try:
            response = self._request('GET', '/api/zones/list')
            
            if response.status_code == 200:
                data = response.json()
                zones = data.get('zones', [])
                logger.info(f"Retrieved {len(zones)} zones")
                return zones
            else:
                logger.error(f"Failed to list zones: {response.status_code}")
                return []
        
        except Exception as e:
            logger.error(f"Exception listing zones: {e}")
            return []
    
    def get_zone_records(self, zone: str) -> List[Dict]:
        """Get all records in a zone"""
        try:
            zone_name = zone.rstrip('.')
            response = self._request('GET', f'/api/zones/records/list', params={'zone': zone_name})
            
            if response.status_code == 200:
                data = response.json()
                records = data.get('records', [])
                logger.info(f"Retrieved {len(records)} records from {zone}")
                return records
            else:
                return []
        
        except Exception as e:
            logger.error(f"Exception getting zone records: {e}")
            return []


class TechnitiumAdapter:
    """Thin wrapper that exposes Holmes-friendly helper methods for Technitium."""

    def __init__(self) -> None:
        settings = get_settings()
        self.client = TechnitiumClient(
            api_url=str(settings.technitium_api_url),
            api_token=settings.technitium_api_token,
        )

    def ensure_zone(self, zone: str) -> Tuple[bool, Optional[str]]:
        """Ensure the zone exists, creating it if needed."""
        fqdn_zone = zone.rstrip('.')
        zones = self.client.list_zones()
        
        # Check if zone exists
        zone_names = [z.get('name', '').rstrip('.') for z in zones]
        if fqdn_zone in zone_names:
            return True, None

        logger.info("Zone %s not found. Creating via Technitium API.", fqdn_zone)
        return self.client.create_zone(zone_name=fqdn_zone)

    def upsert_record(
        self,
        zone: str,
        name: str,
        record_type: str,
        content: str,
        ttl: int,
    ) -> Tuple[bool, Optional[str]]:
        """Create or replace a DNS record."""
        return self.client.add_record(
            zone=zone,
            name=name,
            record_type=record_type,
            content=content,
            ttl=ttl,
        )


technitium_adapter = TechnitiumAdapter()

